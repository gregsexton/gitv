#Readme

This repository represents the latest bleeding-edge changes to gitv.
Please help me find and remove any bugs by adding any problems you have
to the issues tracker of this repository. Suggestions, pull requests and
patches are also all very welcome. To download the latest stable release
see the [gitv page on vim.org](http://www.vim.org/scripts/script.php?script_id=3574).

__Update:__ I have added an exciting new feature that allows you to pass
a range to gitv. This has no effect in browser mode. In file mode
however, only commits that affect at least one line in the range will be
displayed. This is useful, for example, to view the commit history for a
function and all of the changes made to it. You can easily watch the
function 'evolve' as you move from commit to commit. For more
information see the gitv documentation. If you have any problems with
this new feature be sure to add them to the issues tracker.

You can see screenshots of the new range feature in action
[here](http://www.gregsexton.org/2011/05/gitv-range/).

##Introduction

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

This plugin is an extension of the fugitive plugin.

I hope you like it!

## Installation

Install in ~/.vim, or in ~\vimfiles if you're on Windows. This
plugin should be fully pathogen compatible if you want to install
it this way.

gitv was developed against Vim 7.3 but earlier versions of Vim
should work.  Vim 7.2+ is recommended as it ships with syntax
highlighting for many Git file types. **You will also need the
fugitive plugin installed and working for gitv to work.**

## Screenshots and Links

Here is a screenshot to keep you going.

![gitv](http://www.gregsexton.org/images/gitk-vim.jpg)

More can be found at the homepage for gitv:
http://www.gregsexton.org/portfolio/gitv/

You can download stable release versions (and vote for gitv!) at
[gitv’s page](http://www.vim.org/scripts/script.php?script_id=3574) on
Vim.org.
