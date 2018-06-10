"AUTHOR:     Greg Sexton <gregsexton@gmail.com>
"MAINTAINER: Roger Bongers <r.l.bongers@gmail.com>
"WEBSITE:    http://www.gregsexton.org/portfolio/gitv/
"LICENSE:    Same terms as Vim itself (see :help license).
" Gitv line-related utility functions

if exists('g:autoloaded_gitv_util_line')
    finish
endif
let g:autoloaded_gitv_util_line = 1

fu! gitv#util#line#sha(lineNumber) "{{{
    let l = getline(a:lineNumber)
    let sha = matchstr(l, "\\[\\zs[0-9a-f]\\{7,40}\\ze\\]$")
    return sha
endf "}}}

fu! gitv#util#line#refs(line) "{{{
    let l = getline(a:line)
    let refstr = matchstr(l, "^\\(\\(|\\|\\/\\|\\\\\\|\\*\\)\\s\\?\\)*\\s\\+(\\zs.\\{-}\\ze)")
    let refs = split(refstr, ', \| -> ')
    return refs
endf "}}}

 " vim:set et sw=4 ts=4 fdm=marker:
