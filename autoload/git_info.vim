let s:last_dir = ''
let s:job_branch = -2
let s:job_status = -2
let s:job_diff = -2
let s:job_timestamp = -2

let s:info_branch_name = ''
let s:info_changes = {
      \ 'insertions': 0,
      \ 'deletions': 0,
      \ 'untracked': 0,
      \ 'changed': 0,
      \ 'as_string': '',
      \ }
let s:info_last_commit_timestamp = -1

function! git_info#branch_name()
  return s:info_branch_name
endfunction

function! git_info#changes()
  return s:info_changes
endfunction

function! git_info#last_commit_timestamp()
  return s:info_last_commit_timestamp
endfunction

" The status details are gathered from two different commands, so instead
" of having to jobwait() on one of them when the other completes first
" we have both of them check if they're ready to proceed.
" This shouldn't have any race conditions since the responses will be
" handled sequentially.
let s:job_diff_response = -1
let s:job_status_response = -1

function! git_info#stop_jobs()
  let l:jobs = [s:job_branch, s:job_status, s:job_diff, s:job_timestamp]
  map(l:jobs, {i, jid -> jid > 0 ? jobstop(jid) : jid})
endfunction

function! git_info#run_jobs()
  " we have the option of:
  "
  " a) stopping all jobs then restarting them again on save or
  " b) not running jobs if we have existing jobs
  "
  " a means we might never complete a job for huge repositories (theoretically...)
  " and b means we might sit with outdated data, so it seems to me that it's better
  " to just let jobs be, theoretically long running jobs will still finish in order
  let l:working_dir = fnamemodify(resolve(expand('%')), ':p:h')
  if isdirectory(l:working_dir) == v:false
    return
  endif

  " we're starting our jobs so make sure these are set to empty so
  " the completion check doesnt fail
  let s:job_diff_response = -1
  let s:job_status_response = -1

  let l:job_branch = jobstart(['git', 'symbolic-ref', '--short', 'HEAD'], {
        \ 'on_stdout': function('s:git_branch_job_cb'),
        \ 'stdout_buffered': v:true,
        \ 'cwd': l:working_dir,
        \ })
  let l:job_diff = jobstart(['git', 'diff', '--shortstat', 'HEAD'], {
        \ 'on_stdout': function('s:git_diff_job_cb'),
        \ 'stdout_buffered': v:true,
        \ 'cwd': l:working_dir,
        \ })
  let l:job_status = jobstart(['git', 'status', '--porcelain'], {
        \ 'on_stdout': function('s:git_status_job_cb'),
        \ 'stdout_buffered': v:true,
        \ 'cwd': l:working_dir,
        \ })
  let l:job_timestamp = jobstart(['git', 'show', '-s', '--format=%ct', 'HEAD'], {
        \ 'on_stdout': function('s:git_timestamp_job_cb'),
        \ 'stdout_buffered': v:true,
        \ 'cwd': l:working_dir,
        \ })
endfunction

function! s:git_timestamp_job_cb(job, lines, event)
  let l:timestamp = str2nr(a:lines[0])
  if l:timestamp == 0
    let g:git_info_last_commit_timestamp = -1
    let s:info_last_commit_timestamp = -1
  else
    let g:git_info_last_commit_timestamp = l:timestamp
    let s:info_last_commit_timestamp = l:timestamp
  endif
  let s:job_timestamp = -2
endfunction

function! s:git_branch_job_cb(job, lines, event)
  let g:git_info_branch_name = a:lines[0]
  let s:info_branch_name = a:lines[0]
  let s:job_branch = -2
endfunction

function! s:git_diff_job_cb(job, lines, event)
  let s:job_diff_response = a:lines[0]
  let s:job_diff = -2
  " check pair function is finished, else it's done in the other
  if s:job_status_response != -1
    call s:handle_diff_and_status_responses(s:job_diff_response, s:job_status_response)
  endif
endfunction

function! s:git_status_job_cb(job, lines, event)
  " have to filter out all lines that start with ??
  let l:untracked = len(filter(a:lines, 'v:val =~? ''\v^\?\?'''))
  let s:job_status_response = l:untracked
  let s:job_status = -2
  " check pair function is finished, else it's done in the other
  if s:job_diff_response != -1
    call s:handle_diff_and_status_responses(s:job_diff_response, s:job_status_response)
  endif
endfunction

function! s:handle_diff_and_status_responses(diff, status)
  let l:details = git_info#_extract_git_status_details(a:diff, a:status)
  call git_info#_update_changes_variable(l:details)
endfunction

function! git_info#_update_changes_variable(details)
  let g:git_info_changes = a:details

  let l:phrase = ''

  if a:details.changed > 0
    let l:phrase = 'Δ' . a:details.changed
    if a:details.insertions > 0 || a:details.deletions > 0
      let l:phrase .= '±' . a:details.insertions . '/' . a:details.deletions
    endif
  endif

  " any add untracked if any, prepend no changes if we haven't
  " added any by now
  if a:details.untracked > 0
    if len(l:phrase) == 0
      let l:phrase .= 'Δ0'
    endif
    let l:phrase .= '∌'. a:details.untracked
  endif

  let g:git_info_changes.as_string = l:phrase

  let s:info_changes = a:details
  let s:info_changes.as_string = l:phrase
endfunction

function! git_info#_extract_git_status_details(diff, untracked)
  let l:untracked = a:untracked
  let l:diff = a:diff
  let l:details = {}
  let l:details.untracked = 0
  let l:details.changed = 0
  let l:details.insertions = 0
  let l:details.deletions = 0

  " early exit if we didn't get anything
  if l:untracked == 0 && len(l:diff) == 0
    return l:details
  endif

  if l:untracked > 0
    let l:details.untracked = l:untracked
  endif

  " parse out the diff stats
  let l:changed_pattern = '\v(\d+) files? changed'
  let l:insertion_pattern = '\v, (\d+) insertion'
  let l:deletion_pattern = '\v, (\d+) deletion'
  let l:changed_count = matchlist(l:diff, l:changed_pattern)
  let l:insertion_count = matchlist(l:diff, l:insertion_pattern)
  let l:deletion_count = matchlist(l:diff, l:deletion_pattern)

  if len(l:changed_count)
    let l:details.changed = str2nr(l:changed_count[1])
  endif
  if len(l:insertion_count)
    let l:details.insertions = str2nr(l:insertion_count[1])
  endif
  if len(l:deletion_count)
    let l:details.deletions = str2nr(l:deletion_count[1])
  endif

  return l:details
endfunction

