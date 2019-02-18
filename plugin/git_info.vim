" exposed globals for user
let g:git_info_last_commit_timestamp = -1
let g:git_info_branch_name = ""
let g:git_info_changes = {
      \ 'insertions': 0,
      \ 'deletions': 0,
      \ 'untracked': 0,
      \ 'changed': 0,
      \ 'as_string': 0,
      \ }

"TODO let g:git_info_remote_ahead = 0
"TODO let g:git_info_remote_behind = 0

augroup git_info_augroup
  autocmd!
  autocmd BufEnter * call git_info#run_jobs()
  autocmd BufWritePost * call git_info#run_jobs()
augroup END
