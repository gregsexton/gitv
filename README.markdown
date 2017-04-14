# Readme

This repository represents the latest bleeding-edge changes to gitv.
Please help me find and remove any bugs by adding any problems you have
to the issues tracker of this repository. Suggestions, pull requests and
patches are also all very welcome. To download the latest stable release
see the [gitv page on vim.org](http://www.vim.org/scripts/script.php?script_id=3574).

Future changes are viewable in [the roadmap](https://github.com/gregsexton/gitv/blob/master/roadmap.md).
A tentative release schedule is available in [the milestone view](https://github.com/gregsexton/gitv/milestones).

The newest features to gitv are interactive rebasing, interactive bisecting,
and a robust key remapping system. View `:help gitv` for more. If you encounter
any bugs or have any suggestions for this system (which we are actively looking
for for a future release), be sure to add them to the issues tracker.

You can download stable release versions (and vote for gitv!) at
[gitv’s page](http://www.vim.org/scripts/script.php?script_id=3574) on
Vim.org.

## Introduction

gitv is a 'gitk clone' plugin for the text editor Vim. The goal is
to give you a similar set of functionality as a repository viewer.
Using this plugin you can view a repository's history including
branching and merging, you can see which commits refs point to.
You can quickly and easily view what changed to which files and
when. You can perform arbitrary diffs (using Vim's excellent built
in diff functionality) and you can easily check out whole commits
and branches or just individual files if need be.

Throw in the fact that it is running in Vim and you get for free:
the ability to move over repository history quickly and precisely
using Vim's built in movement operators. You get excellent code
syntax highlighting due to Vim's built in ability. You can open up
all sorts of repository views in multiple windows and position
them exactly how you like. You can take advantage of Vim's
registers to copy multiple fragments of code from previous
commits. The list goes on.

Start the plugin by running :Gitv in Vim when viewing a file in a git repository.

This plugin is an extension of the [tpope/fugitive](https://github.com/tpope/vim-fugitive) plugin.

I hope you like it!

## Installation

Install in ~/.vim, or in ~\vimfiles if you're on Windows. This
plugin should be fully compatible with any plugin managers that
support git if you want to install it this way.

gitv was developed against Vim 7.3 and later 8.0 but earlier
versions of Vim should work.  Vim 7.2+ is recommended as it
ships with syntax highlighting for many Git file types.
**You will also need the
[tpope/fugitive](https://github.com/tpope/vim-fugitive) plugin installed and working for gitv to work.**

## Screenshots

![gitv file mode commit preview](http://raw.github.com/gregsexton/gitv/master/img/gitv-file-commit.png)
![gitv file mode diffsplit](http://raw.github.com/gregsexton/gitv/master/img/gitv-file-diffsplit.png)
![gitv file mode diffstat](http://raw.github.com/gregsexton/gitv/master/img/gitv-file-diffstat.png)
![gitv interactive bisecting](http://raw.github.com/gregsexton/gitv/master/img/gitv-bisecting.png)
![gitv interactive rebasing](http://raw.github.com/gregsexton/gitv/master/img/gitv-rebasing.png)
