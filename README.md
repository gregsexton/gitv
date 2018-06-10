# Readme

gitv is a repository viewer similar to gitk. It is an extension of the
[fugitive git plugin][5] for vim. It is essentially a wrapper around
`git log --graph`, allowing you to see your branching history. It allows you to
view commits, diffstats, inline diffs, and file or folder specific history, and
more. It allows you to perform operations on the commit tree interactively,
such as merges, cherry picks, reversions, resets, deletions, checkouts,
bisections, and rebase operations.

This repo has the most bleeding edge version of gitv. Stable versions are
available at [the vim.org page][1].

[Bugs, suggestions,][2] [pull requests and patches][3] are all very welcome.

We are currently actively looking for feature requests and bugs regarding the
latest [pre-release][4].

## Basic usage

Start the plugin by running :Gitv in Vim when viewing a file in a git repository.

This plugin is an extension of the [fugitive git plugin][5] by Tim Pope.

I hope you like it!

## Installation

You will need the [tpope/fugitive][5] plugin installed and working for gitv to work.

For Windows, use the `~\vimfiles` directory instead of `~/.vim`


| Method         | Instalation instructions                                                                                       |
| -------------- | -------------------------------------------------------------------------------------------------------------- |
| Manual         | Merge the `autoload`, `doc`, `ftplugin`, `plugin`, and `syntax` folders into their respective `~/.vim` folders |
| [NeoBundle][6] | Add `NeoBundle 'gregsexton/gitv'` to `.vimrc`                                                                  |
| [Pathogen][7]  | Run `git clone https://github.com/gregsexton/gitv ~/.vim/bundle/gitv`                                          |
| [Plug][8]      | Add `Plug 'gregsexton/gitv', {'on': ['Gitv']}` to `.vimrc`                                                     |
| [Vundle][9]    | Add `Plugin 'gregsexton/gitv'` to `.vimrc`                                                                     |

### Compatibility

gitv was developed against Vim 7.3 and later 8.0 but earlier versions of Vim
should work. Vim 7.2+ is recommended as it ships with syntax highlighting for
many Git file types. Vim 7.3+ is recommended for UTF-8 support.

gitv now has basic neovim support.

## Purpose

gitv is a 'gitk clone' plugin for the text editor Vim. The goal is to give you
a similar set of functionality as a repository viewer. Using this plugin you
can view a repository's history including branching and merging, you can see
which commits refs point to. You can quickly and easily view what changed to
which files and when. You can perform arbitrary diffs (using Vim's excellent
built in diff functionality) and you can easily check out whole commits and
branches or just individual files if need be.

Throw in the fact that it is running in Vim and you get for free: the ability
to move over repository history quickly and precisely using Vim's built in
movement operators. You get excellent code syntax highlighting due to Vim's
built in ability. You can open up all sorts of repository views in multiple
windows and position them exactly how you like. You can take advantage of Vim's
registers to copy multiple fragments of code from previous commits. The list
goes on.

## Links

Click [here][10] for help on our official [matrix.org][11] server.

Future changes are viewable in [the roadmap][12].

A tentative release schedule is available in [the milestone view][13].

You can download stable release versions (and vote for gitv!) at
[gitv’s page][1] on `vim.org`.

## Screenshots

### commit preview

![gitv commit preview](http://raw.github.com/gregsexton/gitv/master/img/gitv-commit.png)

### diff splitting

![gitv diffsplit](http://raw.github.com/gregsexton/gitv/master/img/gitv-diffsplit.png)

### diff stat-ing

![gitv diffstat](http://raw.github.com/gregsexton/gitv/master/img/gitv-diffstat.png)

### interactive bisecting

![gitv interactive bisecting](http://raw.github.com/gregsexton/gitv/master/img/gitv-bisecting.png)

### interactive rebasing

![gitv interactive rebasing](http://raw.github.com/gregsexton/gitv/master/img/gitv-rebasing.png)

[1]: http://www.vim.org/scripts/script.php?script_id=3574
[2]: https://github.com/gregsexton/gitv/issues
[3]: https://github.com/gregsexton/gitv/pulls
[4]: https://github.com/gregsexton/gitv/releases/tag/v1.3.1
[5]: https://github.com/tpope/vim-fugitive
[6]: https://github.com/Shougo/neobundle.vim
[7]: https://github.com/tpope/vim-pathogen
[8]: https://github.com/junegunn/vim-plug
[9]: https://github.com/gmarik/vundle
[10]: https://riot.im/app/#/room/#gitv:matrix.org
[11]: http://matrix.org/
[12]: https://github.com/gregsexton/gitv/blob/master/ROADMAP.md
[13]: https://github.com/gregsexton/gitv/milestones
[15]: http://www.vim.org/scripts/script.php?script_id=3574
