augroup git_info_augroup
  autocmd!
  autocmd BufEnter * call git_info#run_jobs()
  autocmd BufWritePost * call git_info#run_jobs()
augroup END
