# git-info.vim

A **neovim** plugin that extracts git repo information to a few global variables for use in your status line (or other things).

Information is extracted via background jobs either on buffer load and save or at a regular interval.

Information is relative to the current buffer, not vim current working directory.

# Installation

## Using [vim-plug](https://github.com/junegunn/vim-plug)

    Plug 'rktjmp/git-info.vim'

# Usage

`git-info` exposes the following variables:

- `g:git_info_branch_phrase`: the name of the current branch.

- `g:git_info_last_commit_timestamp`: a number representing the unix timestamp of the last git commit. `-1` if no commit has been made. You can conver this to a readable format with [time-ago.vim](http://github.com/rktjmp/time-ago.vim) ('10 days ago') or to date with `strftime`. 

- `g:git_info_status_details`: a map of integers, containing the following keys:
  - `changed`: number of files with uncommitted changes.
  - `insertions`: number of `diff` insertions (linewise). (see note below)
  - `deletions`: number of `diff` deletions (linewise).
  - `untracked`: number of untracked files in the repository directory.

- `g:git_info_status_phrase`: a condensed & opinionated representation of `g:git_info_status_details`. `''` if no changes or untracked files.
  - `Δ2±3/4∌1`: should be read as "the repo delta contains 2 altered files with 3 insertions and 4 deletions. 1 file is untracked (not included in the change set)".
  - `Δ5±0/6`: 5 files changed, 0 insertions, 6 deletions, no untracked files
  - `Δ0∌2`: 0 files changed, 2 untracked files

- `g:git_info_dirty_flag`: an opinionated "dirty repository" flag. `git-info`  considers a repository dirty if it contains any changed files *or* any untracked files. You can inspect `g:git_info_status_details` if you prefer a different definition.

# Notes

- Renaming a file with no changes will return 1 file changed and 0 insertions, 0 deletions, 0 untracked.
- Due to the behaviour of git, status details may not be what you expect until at least one commit has been made to a repository.

# Bugs

You will sometimes see spurious counts for 'untracked files' when another process is watching for changes in a file you edit.

An example of this might be `exuberant ctags` if set to create tag files in your working dir.

On save, ctags will create `tags.temp` and `tags.lock`, update `tags` then remove `tags.temp` and `tags.lock`. However our `git status` command is run during this time and spots 2 new untracked files.

The solution to this is adding the additional files to your `.gitignore`.
