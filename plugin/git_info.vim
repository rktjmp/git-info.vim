if exists('g:git_info') || &cp 
endif

" exposed globals for user
let g:git_info_last_commit_timestamp = -1
let g:git_info_dirty_flag = 0
let g:git_info_branch_phrase = ""
let g:git_info_status_phrase = ""
let g:git_info_status_details = {
      \ 'insertions': 0,
      \ 'deletions': 0,
      \ 'untracked': 0,
      \ 'changed': 0,
      \ }

"TODO let g:git_info_remote_ahead = 0
"TODO let g:git_info_remote_behind = 0

augroup git_info_augroup
  autocmd!
  autocmd BufEnter * call git_info#run_jobs()
  autocmd BufWritePost * call git_info#run_jobs()
augroup END
