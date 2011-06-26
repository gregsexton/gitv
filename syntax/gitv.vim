" Vim syntax file
" Language:	Custom git log output
" Maintainer:	Greg Sexton <gregsexton@gmail.com>
" Last Change:	2011-04-08
"

if exists("b:current_syntax")
    finish
endif

"set conceallevel=2
"set concealcursor=n

syn match gitvSubject /.*/ 

syn match gitvDate /\(\d\+ years\?, \)\?\d\+ \%(second\|minute\|hour\|day\|week\|month\|year\)s\? ago/ contained containedin=gitvSubject
syn match gitvHash /\[[0-9a-f]\{7}\]$/ contained containedin=gitvSubject

syn match  gitvGraphEdge9 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge0,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge8 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge9,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge7 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge8,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge6 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge7,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge5 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge6,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge4 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge5,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge3 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge4,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge2 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge3,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge1 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge2,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdge0 /_\?\(|\|-\(-\|\.\)\|\/|\?\|\\\|\*\|+\|=\)\s\?/ nextgroup=gitvGraphEdge1,gitvRef,gitvSubject skipwhite
syn match  gitvGraphEdgeH /_/ contained containedin=gitvGraphEdge0,gitvGraphEdge1,gitvGraphEdge2,gitvGraphEdge3,gitvGraphEdge4,gitvGraphEdge5,gitvGraphEdge6,gitvGraphEdge7,gitvGraphEdge8,gitvGraphEdge9

syn match gitvRef /\s*(.\{-})/ nextgroup=gitvSubject skipwhite
syn match gitvRefTag /t:\zs.\{-}\ze\(, \|)\)/ contained containedin=gitvRef
syn match gitvRefRemote /r:\zs.\{-}\ze\(, \|)\)/ contained containedin=gitvRef
syn match gitvRefHead /HEAD/ contained containedin=gitvRef

syn match gitvLoadMore /^-- Load More --$/
syn match gitvWorkingCopy /^-- \[.*\] --$/

syn match gitvRange /^-- Showing .* in the range:$/
syn match gitvRangeFromTo /^-- \/.*\/$/

syn match gitvLocalUncommit /Local uncommitted changes, not checked in to index\.$/ contained containedin=gitvSubject
syn match gitvLocalCommited /Local changes checked in to index but not committed\.$/ contained containedin=gitvSubject
syn match gitvLocalCommitedNode /+/ contained containedin=gitvGraphEdge0,gitvGraphEdge1,gitvGraphEdge2,gitvGraphEdge3,gitvGraphEdge4,gitvGraphEdge5,gitvGraphEdge6,gitvGraphEdge7,gitvGraphEdge8,gitvGraphEdge9
syn match gitvLocalUncommitNode /=/ contained containedin=gitvGraphEdge0,gitvGraphEdge1,gitvGraphEdge2,gitvGraphEdge3,gitvGraphEdge4,gitvGraphEdge5,gitvGraphEdge6,gitvGraphEdge7,gitvGraphEdge8,gitvGraphEdge9

syn match gitvAddedMarks /|\s\+\d\+ \zs+*-*\ze$/ contained containedin=gitvSubject
syn match gitvAddedMarks /|\s\+Bin \zs\d\+ -> \d\+\ze bytes$/ contained containedin=gitvSubject
syn match gitvRemovedMarks /-*$/ contained containedin=gitvAddedMarks
syn match gitvRemovedMarks /\d\+\ze ->/ contained containedin=gitvAddedMarks
syn match gitvSeperatorMarks /\s\+->\s\+/ contained containedin=gitvAddedMarks

hi def link gitvHash              Number
hi def link gitvRef               Directory
hi def link gitvRefTag            String
hi def link gitvRefRemote         Statement
hi def link gitvRefHead           Special
hi def link gitvDate              Statement
hi def link gitvSubject           Normal
hi def link gitvLoadMore          Question
hi def link gitvWorkingCopy       Question
hi def link gitvRange             ModeMsg
hi def link gitvRangeFromTo       Function

hi def link gitvAddedMarks        diffAdded
hi def link gitvRemovedMarks      diffRemoved
hi def link gitvSeperatorMarks    Normal

hi def link gitvGraphEdge0        Delimiter

if &background == "dark"
    highlight default gitvGraphEdge1 ctermfg=magenta     guifg=green1
    highlight default gitvGraphEdge2 ctermfg=green       guifg=yellow1
    highlight default gitvGraphEdge3 ctermfg=yellow      guifg=orange1
    highlight default gitvGraphEdge4 ctermfg=cyan        guifg=greenyellow
    highlight default gitvGraphEdge5 ctermfg=red         guifg=springgreen1
    highlight default gitvGraphEdge6 ctermfg=yellow      guifg=cyan1
    highlight default gitvGraphEdge7 ctermfg=green       guifg=slateblue1
    highlight default gitvGraphEdge8 ctermfg=cyan        guifg=magenta1
    highlight default gitvGraphEdge9 ctermfg=magenta     guifg=purple1
else
    highlight default gitvGraphEdge1 ctermfg=darkyellow  guifg=orangered3
    highlight default gitvGraphEdge2 ctermfg=darkgreen   guifg=orange2
    highlight default gitvGraphEdge3 ctermfg=blue        guifg=yellow3
    highlight default gitvGraphEdge4 ctermfg=darkmagenta guifg=olivedrab4
    highlight default gitvGraphEdge5 ctermfg=red         guifg=green4
    highlight default gitvGraphEdge6 ctermfg=darkyellow  guifg=paleturquoise3
    highlight default gitvGraphEdge7 ctermfg=darkgreen   guifg=deepskyblue4
    highlight default gitvGraphEdge8 ctermfg=blue        guifg=darkslateblue
    highlight default gitvGraphEdge9 ctermfg=darkmagenta guifg=darkviolet
endif

highlight default gitvLocalCommitedNode ctermfg=green guifg=green
highlight default gitvLocalUncommitNode ctermfg=red   guifg=red
highlight default gitvLocalCommited     gui=bold
highlight default gitvLocalUncommit     gui=bold

let b:current_syntax = "gitv"
