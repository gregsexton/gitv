"AUTHOR:   Greg Sexton <gregsexton@gmail.com>
"WEBSITE:  http://www.gregsexton.org/portfolio/gitv/
"LICENSE:  Same terms as Vim itself (see :help license).
"NOTES:    Much of the credit for gitv goes to Tim Pope and the fugitive plugin
"          where this plugin either uses functionality directly or was inspired heavily.

"enabling these next lines breaks settings when reloading the buffer
"if exists("b:did_ftplugin") | finish | endif
"let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal fdm=expr

fu! Foldlevelforbranch() "{{{
    let line = getline(v:lnum)

    if line == "-- Load More --"
        return 0
    endif
    if line =~ "^-- \\[.*\\] --$"
        return 0
    endif

    let line = substitute(line, "\\s", "", "g")
    let level = match(line, "*") + 1
    return level == 0 ? -1 : level
endfu "}}}
setlocal foldexpr=Foldlevelforbranch()

fu! BranchFoldText() "{{{
    "get first non-blank line
    let fs = v:foldstart
    while getline(fs) =~ '^\s*$' | let fs = nextnonblank(fs + 1)
    endwhile
    if fs > v:foldend
        let line = getline(v:foldstart)
    else
        let line = getline(fs)
    endif
    return line
endf "}}}
setlocal foldtext=BranchFoldText()
setlocal foldlevel=99

let &cpo = s:cpo_save
unlet s:cpo_save
