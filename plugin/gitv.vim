"AUTHOR:   Greg Sexton <gregsexton@gmail.com>
"WEBSITE:  http://www.gregsexton.org/portfolio/gitv/
"LICENSE:  Same terms as Vim itself (see :help license).
"NOTES:    Much of the credit for gitv goes to Tim Pope and the fugitive plugin
"          where this plugin either uses functionality directly or was inspired heavily.

if exists("g:loaded_gitv") || v:version < 700
  finish
endif
let g:loaded_gitv = 1

let s:savecpo = &cpo
set cpo&vim

"configurable options:
"g:Gitv_CommitStep             - int
"g:Gitv_OpenHorizontal         - {0,1,'AUTO'}
"g:Gitv_GitExecutable          - string
"g:Gitv_WipeAllOnClose         - int
"g:Gitv_WrapLines              - {0,1}
"g:Gitv_TruncateCommitSubjects - {0,1}

if !exists("g:Gitv_CommitStep")
    let g:Gitv_CommitStep = &lines
endif

if !exists('g:Gitv_GitExecutable')
    let g:Gitv_GitExecutable = 'git'
endif

if !exists('g:Gitv_WipeAllOnClose')
    let g:Gitv_WipeAllOnClose = 0 "default for safety
endif

if !exists('g:Gitv_WrapLines')
    let g:Gitv_WrapLines = 0
endif

if !exists('g:Gitv_TruncateCommitSubjects')
    let g:Gitv_TruncateCommitSubjects = 0
endif

if !exists('g:Gitv_OpenPreviewOnLaunch')
    let g:Gitv_OpenPreviewOnLaunch = 1
endif

"this counts up each time gitv is opened to ensure a unique file name
let g:Gitv_InstanceCounter = 0

let s:localUncommitedMsg = '*  Local uncommitted changes, not checked in to index.'
let s:localCommitedMsg   = '*  Local changes checked in to index but not committed.'

command! -nargs=* -bang Gitv call s:OpenGitv(shellescape(<q-args>), <bang>0)
cabbrev gitv Gitv

"Public API:"{{{
fu! Gitv_OpenGitCommand(command, windowCmd, ...) "{{{
    "returns 1 if command succeeded with output
    "optional arg is a flag, if present runs command verbatim

    "this function is not limited to script scope as is useful for running other commands.
    "e.g call Gitv_OpenGitCommand("diff --no-color", 'vnew') is useful for getting an overall git diff.

    let [result, finalCmd] = s:RunGitCommand(a:command, a:0)

    if type(result) == type(0)
        return 0
    endif
    if type(result) == type("") && result == ""
        echom "No output."
        return 0
    else
        if a:windowCmd == ''
            silent setlocal modifiable
            silent setlocal noreadonly
            1,$ d
        else
            let goBackTo       = winnr()
            let dir            = s:GetRepoDir()
            let workingDir     = fnamemodify(dir,':h')
            let cd             = exists('*haslocaldir') && haslocaldir() ? 'lcd ' : 'cd '
            let bufferDir      = getcwd()
            let tempSplitBelow = &splitbelow
            let tempSplitRight = &splitright
            try
                set nosplitbelow
                set nosplitright
                execute cd.'`=workingDir`'
                exec a:windowCmd
                let newWindow = winnr()
            finally
                exec goBackTo . 'wincmd w'
                execute cd.'`=bufferDir`'
                if exists('newWindow')
                    exec newWindow . 'wincmd w'
                endif
                exec 'set '. (tempSplitBelow ? '' : 'no') . 'splitbelow'
                exec 'set '. (tempSplitRight ? '' : 'no') . 'splitright'
            endtry
        endif
        if !(&modifiable)
            return 0
        endif
        let b:Git_Command = finalCmd
        silent setlocal ft=git
        silent setlocal buftype=nofile
        silent setlocal nobuflisted
        silent setlocal noswapfile
        silent setlocal bufhidden=wipe
        silent setlocal nonumber
        if g:Gitv_WrapLines
            silent setlocal wrap
        else
            silent setlocal nowrap
        endif
        silent setlocal fdm=syntax
        silent setlocal foldlevel=0
        nmap <buffer> <silent> q :q!<CR>
        nmap <buffer> <silent> u :if exists('b:Git_Command')<bar>call Gitv_OpenGitCommand(b:Git_Command, '', 1)<bar>endif<cr>
        call append(0, split(result, '\n')) "system converts eols to \n regardless of os.
        silent setlocal nomodifiable
        silent setlocal readonly
        1
        return 1
    endif
endf "}}} }}}
"General Git Functions: "{{{
fu! s:RunGitCommand(command, verbatim) "{{{
    "if verbatim returns result of system command, else
    "switches to the buffer repository before running the command and switches back after.
    if !a:verbatim
        "switches to the buffer repository before running the command and switches back after.
        let dir        = s:GetRepoDir()
        let workingDir = fnamemodify(dir,':h')
        if workingDir == ''
            return 0
        endif

        let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd ' : 'cd '
        let bufferDir = getcwd()
        try
            execute cd.'`=workingDir`'
            let finalCmd = g:Gitv_GitExecutable.' --git-dir="' .dir. '" ' . a:command
            let result   = system(finalCmd)
        finally
            execute cd.'`=bufferDir`'
        endtry
    else
        let result   = system(a:command)
        let finalCmd = a:command
    endif
    return [result, finalCmd]
endfu "}}}
fu! s:GetRepoDir() "{{{
    let dir = fugitive#buffer().repo().dir()
    if dir == ''
        echom "No git repository could be found."
    endif
    return dir
endfu "}}} }}}
"Open And Update Gitv:"{{{
fu! s:OpenGitv(extraArgs, fileMode) "{{{
    let sanatizedArgs = a:extraArgs   == "''" ? '' : a:extraArgs
    let sanatizedArgs = sanatizedArgs == '""' ? '' : sanatizedArgs
    let g:Gitv_InstanceCounter += 1
    if !s:IsCompatible() "this outputs specific errors
        return
    endif
    try
        if a:fileMode
            call s:OpenFileMode(sanatizedArgs)
        else
            call s:OpenBrowserMode(sanatizedArgs)
        endif
    catch /not a git repository/
        echom 'Not a git repository.'
        return
    endtry
endf "}}}
fu! s:IsCompatible() "{{{
    if !exists('g:loaded_fugitive')
        echoerr "gitv requires the fugitive plugin to be installed."
    endif
    return exists('g:loaded_fugitive')
endfu "}}}
fu! s:OpenBrowserMode(extraArgs) "{{{
    "this throws an exception if not a git repo which is caught immediately
    let fubuffer = fugitive#buffer()
    silent Gtabedit HEAD

    if s:IsHorizontal()
        let direction = 'new gitv'.'-'.g:Gitv_InstanceCounter
    else
        let direction = 'vnew gitv'.'-'.g:Gitv_InstanceCounter
    endif
    if !s:LoadGitv(direction, 0, g:Gitv_CommitStep, a:extraArgs, '')
        return 0
    endif
    call s:SetupBufferCommands(0)
    "open the first commit
    if g:Gitv_OpenPreviewOnLaunch
        silent call s:OpenGitvCommit("Gedit", 0)
    else
        call s:MoveIntoPreviewAndExecute('bwipeout', 0)
    endif
endf "}}}
fu! s:OpenFileMode(extraArgs) "{{{
    let relPath = fugitive#buffer().path()
    pclose!
    if !s:LoadGitv(&previewheight . "new gitv".'-'.g:Gitv_InstanceCounter, 0, g:Gitv_CommitStep, a:extraArgs, relPath)
        return 0
    endif
    set previewwindow
    set winfixheight
    let b:Gitv_FileMode = 1
    let b:Gitv_FileModeRelPath = relPath
    call s:SetupBufferCommands(1)
endf "}}}
fu! s:LoadGitv(direction, reload, commitCount, extraArgs, filePath) "{{{
    if a:reload
        let jumpTo = line('.') "this is for repositioning the cursor after reload
    endif

    if !s:ConstructAndExecuteCmd(a:direction, a:reload, a:commitCount, a:extraArgs, a:filePath)
        return 0
    endif
    call s:SetupBuffer(a:commitCount, a:extraArgs, a:filePath)
    exec exists('jumpTo') ? jumpTo : '1'
    call s:SetupMappings() "redefines some of the mappings made by Gitv_OpenGitCommand
    call s:ResizeWindow(a:filePath!='')

    echom "Loaded up to " . a:commitCount . " commits."
    return 1
endf "}}}
fu! s:ConstructAndExecuteCmd(direction, reload, commitCount, extraArgs, filePath) "{{{
    if a:reload "run the same command again with any extra args
        if exists('b:Git_Command')
            "substitute in the potentially new commit count taking account of a potential filePath
            let newcmd = b:Git_Command
            if a:filePath != ''
                let newcmd = substitute(newcmd, " -- " . a:filePath . "$", "", "")
            endif
            let newcmd = substitute(newcmd, " -\\d\\+$", " -" . a:commitCount, "")
            if a:filePath != ''
                let newcmd .= ' -- ' . a:filePath
            endif
            silent let res = Gitv_OpenGitCommand(newcmd, a:direction, 1)
            return res
        endif
    else
        let cmd  = "log " . a:extraArgs 
        let cmd .= " --no-color --decorate=full --pretty=format:\"%d %s__SEP__%ar__SEP__%an__SEP__[%h]\" --graph -" 
        let cmd .= a:commitCount
        if a:filePath != ''
            let cmd .= ' -- ' . a:filePath
        endif
        silent let res = Gitv_OpenGitCommand(cmd, a:direction)
        return res
    endif
    return 0
endf "}}}
fu! s:SetupBuffer(commitCount, extraArgs, filePath) "{{{
    silent set filetype=gitv
    let b:Gitv_CommitCount = a:commitCount
    let b:Gitv_ExtraArgs   = a:extraArgs
    silent setlocal modifiable
    silent setlocal noreadonly
    silent %s/refs\/tags\//t:/ge
    silent %s/refs\/remotes\//r:/ge
    silent %s/refs\/heads\///ge
    silent %call s:Align("__SEP__", a:filePath)
    silent %s/\s\+$//e
    call s:AddLoadMore()
    call s:AddLocalNodes(a:filePath)
    if a:filePath != ''
        call append(0, '-- ['.a:filePath.'] --')
    endif
    silent setlocal nomodifiable
    silent setlocal readonly
    silent setlocal cursorline
endf "}}}
fu! s:AddLocalNodes(filePath) "{{{
    let suffix = a:filePath == '' ? '' : ' -- '.a:filePath
    let gitCmd = "diff --no-color --cached" . suffix
    let [result, cmd] = s:RunGitCommand(gitCmd, 0)
    if result != ""
        call append(0, s:localCommitedMsg)
    endif
    let gitCmd = "diff --no-color" . suffix
    let [result, cmd] = s:RunGitCommand(gitCmd, 0)
    if result != ""
        call append(0, s:localUncommitedMsg)
    endif
endfu "}}}
fu! s:AddLoadMore() "{{{
    call append(line('$'), '-- Load More --')
endfu "}}}
fu! s:SetupMappings() "{{{
    "operations
    nmap <buffer> <silent> <cr> :call <SID>OpenGitvCommit("Gedit", 0)<cr>
    nmap <buffer> <silent> o :call <SID>OpenGitvCommit("Gsplit", 0)<cr>
    nmap <buffer> <silent> O :call <SID>OpenGitvCommit("Gtabedit", 0)<cr>
    nmap <buffer> <silent> s :call <SID>OpenGitvCommit("Gvsplit", 0)<cr>
    "force opening the fugitive buffer for the commit
    nmap <buffer> <silent> <c-cr> :call <SID>OpenGitvCommit("Gedit", 1)<cr>

    nmap <buffer> <silent> q :call <SID>CloseGitv()<cr>
    nmap <buffer> <silent> u :call <SID>LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, <SID>GetRelativeFilePath())<cr>
    nmap <buffer> <silent> co :call <SID>CheckOutGitvCommit()<cr>

    nmap <buffer> <silent> D :call <SID>DiffGitvCommit()<cr>
    vmap <buffer> <silent> D :call <SID>DiffGitvCommit()<cr>

    nmap <buffer> <silent> S :call <SID>StatGitvCommit()<cr>
    vmap <buffer> <silent> S :call <SID>StatGitvCommit()<cr>

    "movement
    nmap <buffer> <silent> x :call <SID>JumpToBranch(0)<cr>
    nmap <buffer> <silent> X :call <SID>JumpToBranch(1)<cr>
    nmap <buffer> <silent> r :call <SID>JumpToRef(0)<cr>
    nmap <buffer> <silent> R :call <SID>JumpToRef(1)<cr>
    nmap <buffer> <silent> P :call <SID>JumpToHead()<cr>
endf "}}}
fu! s:SetupBufferCommands(fileMode) "{{{
    silent command! -buffer -nargs=* -complete=customlist,s:fugitive_GitComplete Git call <sid>MoveIntoPreviewAndExecute("unsilent Git <args>",1)|normal u
endfu "}}}
fu! s:ResizeWindow(fileMode) "{{{
    if a:fileMode "window height determined by &previewheight
        return
    endif
    if !s:IsHorizontal()
        "size window based on longest line
        let longest = max(map(range(1, line('$')), "virtcol([v:val, '$'])"))
        if longest > &columns/2
            "potentially auto change to horizontal
            if s:AutoHorizontal()
                "switching to horizontal
                let b:Gitv_AutoHorizontal=1
                wincmd K
                call s:ResizeWindow(a:fileMode)
                return
            else
                let longest = &columns/2
            endif
        endif
        exec "vertical resize " . longest
    else
        "size window based on num lines
        call s:ResizeHorizontal()
    endif
endf "}}} }}}
"Utilities:"{{{
fu! s:GetGitvSha(lineNumber) "{{{
    let l = getline(a:lineNumber)
    let sha = matchstr(l, "\\[\\zs[0-9a-f]\\{7}\\ze\\]$")
    return sha
endf "}}}
fu! s:GetGitvRefs() "{{{
    let l = getline('.')
    let refstr = matchstr(l, "^\\(\\(|\\|\\/\\|\\\\\\|\\*\\)\\s\\?\\)*\\s\\+(\\zs.\\{-}\\ze)")
    let refs = split(refstr, ', ')
    return refs
endf "}}}
fu! s:RecordBufferExecAndWipe(cmd, wipe) "{{{
    "this should be used to replace the buffer in a window
    let buf = bufnr('%')
    exec a:cmd
    if a:wipe
        "safe guard against wiping out buffer you're in
        if bufnr('%') != buf && bufexists(buf)
            exec 'bwipeout ' . buf
        endif
    endif
endfu "}}}
fu! s:MoveIntoPreviewAndExecute(cmd, tryToOpenNewWin) "{{{
    if winnr("$") == 1 "is the only window
        call s:AttemptToCreateAPreviewWindow(a:tryToOpenNewWin, a:cmd)
        return
    endif
    let horiz      = s:IsHorizontal()
    let filem      = s:IsFileMode()
    let currentWin = winnr()

    if horiz || filem
        wincmd j
    else
        wincmd l
    endif

    if currentWin == winnr() "haven't moved anywhere
        call s:AttemptToCreateAPreviewWindow(a:tryToOpenNewWin, a:cmd)
        return
    endif

    silent exec a:cmd
    if horiz || filem
        wincmd k
    else
        wincmd h
    endif
endfu "}}}
fu! s:AttemptToCreateAPreviewWindow(shouldAttempt, cmd) "{{{
    if a:shouldAttempt
        call s:CreateNewPreviewWindow()
        call s:MoveIntoPreviewAndExecute(a:cmd, 0)
    else
        echoerr "No preview window detected."
    endif
endfu "}}}
fu! s:CreateNewPreviewWindow() "{{{
    "this should not be called by anything other than AttemptToCreateAPreviewWindow
    let horiz      = s:IsHorizontal()
    let filem      = s:IsFileMode()
    if horiz || filem
        Gsplit HEAD
    else
        Gvsplit HEAD
    endif
    wincmd x
endfu "}}}
fu! s:IsHorizontal() "{{{
    "NOTE: this can only tell you if horizontal while cursor in browser window
    let horizGlobal = exists('g:Gitv_OpenHorizontal') && g:Gitv_OpenHorizontal == 1
    let horizBuffer = exists('b:Gitv_AutoHorizontal') && b:Gitv_AutoHorizontal == 1
    return horizGlobal || horizBuffer
endf "}}}
fu! s:AutoHorizontal() "{{{
    return exists('g:Gitv_OpenHorizontal') && 
                \ type(g:Gitv_OpenHorizontal) == type("") && 
                \ g:Gitv_OpenHorizontal ==? 'auto'
endf "}}}
fu! s:IsFileMode() "{{{
    return exists('b:Gitv_FileMode') && b:Gitv_FileMode == 1
endf "}}}
fu! s:ResizeHorizontal() "{{{
    let lines = line('$')
    if lines > (&lines/2)-2
        let lines = (&lines/2)-2
    endif
    exec "resize " . lines
endf "}}}
fu! s:GetRelativeFilePath() "{{{
    return exists('b:Gitv_FileModeRelPath') ? b:Gitv_FileModeRelPath : ''
endf "}}}
fu! s:OpenRelativeFilePath(sha, geditForm) "{{{
    let relPath = s:GetRelativeFilePath()
    if relPath == ''
        return
    endif
    let cmd = a:geditForm . " " . a:sha . ":" . relPath
    let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(a:geditForm=='Gedit').')'
    call s:MoveIntoPreviewAndExecute(cmd, 1)
endf "}}} }}}
"Mapped Functions:"{{{
"Operations: "{{{
fu! s:OpenGitvCommit(geditForm, forceOpenFugitive) "{{{
    if getline('.') == "-- Load More --"
        call s:LoadGitv('', 1, b:Gitv_CommitCount+g:Gitv_CommitStep, b:Gitv_ExtraArgs, s:GetRelativeFilePath())
        return
    endif
    if s:IsFileMode() && getline('.') =~ "^-- \\[.*\\] --$"
        call s:OpenWorkingCopy(a:geditForm)
        return
    endif
    if getline('.') == s:localUncommitedMsg
        call s:OpenWorkingDiff(a:geditForm, 0)
        return
    endif
    if getline('.') == s:localCommitedMsg
        call s:OpenWorkingDiff(a:geditForm, 1)
        return
    endif
    let sha = s:GetGitvSha(line('.'))
    if sha == ""
        return
    endif
    if s:IsFileMode() && !a:forceOpenFugitive
        call s:OpenRelativeFilePath(sha, a:geditForm)
    else
        let cmd = a:geditForm . " " . sha
        let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(a:geditForm=='Gedit').')'
        call s:MoveIntoPreviewAndExecute(cmd, 1)
    endif
endf
fu! s:OpenWorkingCopy(geditForm)
    let fp = s:GetRelativeFilePath()
    let form = a:geditForm[1:] "strip off the leading 'G'
    let cmd = form . " " . fugitive#buffer().repo().tree() . "/" . fp
    let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(form=='edit').')'
    call s:MoveIntoPreviewAndExecute(cmd, 1)
endfu
fu! s:OpenWorkingDiff(geditForm, staged)
    let winCmd = a:geditForm[1:] == 'edit' ? '' : a:geditForm[1:]
    if s:IsFileMode()
        let fp = s:GetRelativeFilePath()
        let suffix = ' -- '.fp
        let g:Gitv_InstanceCounter += 1
        let winCmd = 'new gitv'.'-'.g:Gitv_InstanceCounter
    else
        let suffix = ''
    endif
    if a:staged
        let cmd = 'call Gitv_OpenGitCommand(\"diff --no-color --cached'.suffix.'\", \"'.winCmd.'\")'
    else
        let cmd = 'call Gitv_OpenGitCommand(\"diff --no-color'.suffix.'\", \"'.winCmd.'\")'
    endif
    let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(winCmd=='').')'
    call s:MoveIntoPreviewAndExecute(cmd, 1)
endfu "}}}
fu! s:CheckOutGitvCommit() "{{{
    let allrefs = s:GetGitvRefs()
    let sha = s:GetGitvSha(line('.'))
    if sha == ""
        return
    endif
    let refs   = allrefs + [sha]
    let refstr = join(refs, "\n")
    let choice = confirm("Checkout commit:", refstr . "\nCancel")
    if choice == 0
        return
    endif
    let choice = get(refs, choice-1, "")
    if choice == ""
        return
    endif
    let choice = substitute(choice, "^t:", "", "")
    let choice = substitute(choice, "^r:", "", "")
    if s:IsFileMode()
        let relPath = s:GetRelativeFilePath()
        let choice .= " -- " . relPath
    endif
    exec "Git checkout " . choice
endf "}}}
fu! s:CloseGitv() "{{{
    if s:IsFileMode()
        q
    else
        if g:Gitv_WipeAllOnClose
            silent windo setlocal bufhidden=wipe
        endif
        let moveLeft = tabpagenr() == tabpagenr('$') ? 0 : 1
        tabc
        if moveLeft && tabpagenr() != 1
            tabp
        endif
    endif
endf "}}}
fu! s:DiffGitvCommit() range "{{{
    if !s:IsFileMode()
        echom "Diffing is not possible in browser mode."
        return
    endif
    let shafirst = s:GetGitvSha(a:firstline)
    let shalast  = s:GetGitvSha(a:lastline)
    if shafirst == "" || shalast == ""
        return
    endif
    if a:firstline != a:lastline
        call s:OpenRelativeFilePath(shafirst, "Gedit")
    endif
    call s:MoveIntoPreviewAndExecute("Gdiff " . shalast, a:firstline != a:lastline)
endf "}}} 
fu! s:StatGitvCommit() range "{{{
    let shafirst = s:GetGitvSha(a:firstline)
    let shalast  = s:GetGitvSha(a:lastline)
    if shafirst == "" || shalast == ""
        return
    endif
    let cmd  = 'diff '.shafirst
    if shafirst != shalast
        let cmd .= ' '.shalast
    endif
    let cmd .= ' --stat'
    let cmd = "call s:SetupStatBuffer('".cmd."')"
    if s:IsFileMode()
        exec cmd
    else
        call s:MoveIntoPreviewAndExecute(cmd, 1)
    endif
endf
fu! s:SetupStatBuffer(cmd)
    silent let res = Gitv_OpenGitCommand(a:cmd, s:IsFileMode()?'vnew':'')
    if res
        silent set filetype=gitv
    endif
endfu "}}} }}}
"Movement: "{{{
fu! s:JumpToBranch(backward) "{{{
    if a:backward
        silent! ?|/\||\\?-1
    else
        silent! /|\\\||\//+1
    endif
endf "}}}
fu! s:JumpToRef(backward) "{{{
    if a:backward
        silent! ?^\(\(|\|\/\|\\\|\*\)\s\=\)\+\s\+\zs(
    else
        silent! /^\(\(|\|\/\|\\\|\*\)\s\?\)\+\s\+\zs(/
    endif
endf "}}}
fu! s:JumpToHead() "{{{
    silent! /^\(\(|\|\/\|\\\|\*\)\s\?\)\+\s\+\zs(HEAD/
endf "}}}
"}}} }}}
"Align And Truncate Functions: "{{{
fu! s:Align(seperator, filePath) range "{{{
    let lines = getline(a:firstline, a:lastline)
    call map(lines, 'split(v:val, a:seperator)')

    let newlines = copy(lines)
    call filter(newlines, 'len(v:val)>1')
    let maxLens = s:MaxLengths(newlines)

    let newlines = []
    for tokens in lines
        if len(tokens)>1
            let newline = []
            for i in range(len(tokens))
                let token = tokens[i]
                call add(newline, token . repeat(' ', maxLens[i]-strlen(token)+1))
            endfor
            call add(newlines, newline)
        else
            call add(newlines, tokens)
        endif
    endfor

    if g:Gitv_TruncateCommitSubjects
        call s:TruncateLines(newlines, a:filePath)
    endif

    call map(newlines, "join(v:val)")
    call setline(a:firstline, newlines)
endfu "}}}
fu! s:TruncateLines(lines, filePath) "{{{
    "truncates the commit subject for any line > &columns
    call map(a:lines, "s:TruncateHelp(v:val, a:filePath)")
endfu "}}}
fu! s:TruncateHelp(line, filePath) "{{{
    let length = strlen(join(a:line))
    let maxWidth = s:IsHorizontal() ? &columns : &columns/2
    let maxWidth = a:filePath != '' ? winwidth(0) : maxWidth
    if length > maxWidth
        let delta = length - maxWidth
        "offset = 3 for the elipsis and 1 for truncation
        let offset = 3 + 1
        if a:line[0][-(delta + offset + 1):] =~ "^\\s\\+$"
            let extension = "   "
        else
            let extension = "..."
        endif
        let a:line[0] = a:line[0][:-(delta + offset)] . extension
    endif
    return a:line
endfu "}}}
fu! s:MaxLengths(colls) "{{{
    "precondition: coll is a list of lists of strings -- should be rectangular
    "returns a list of maximum string lengths
    let lengths = []
    for x in a:colls
        for y in range(len(x))
            let length = strlen(x[y])
            if length > get(lengths, y, 0)
                if len(lengths)-1 < y
                    call add(lengths, length)
                else
                    let lengths[y] = length
                endif
            endif
        endfor
    endfor
    return lengths
endfu "}}} }}}
"Fugitive Functions: "{{{
"These functions are lifted directly from fugitive and modified only to work with gitv.
function! s:fugitive_sub(str,pat,rep) abort "{{{
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction "}}}
function! s:fugitive_GitComplete(A,L,P) abort "{{{
  if !exists('s:exec_path')
    let s:exec_path = s:fugitive_sub(system(g:fugitive_git_executable.' --exec-path'),'\n$','')
  endif
  let cmds = map(split(glob(s:exec_path.'/git-*'),"\n"),'s:fugitive_sub(v:val[strlen(s:exec_path)+5 : -1],"\\.exe$","")')
  if a:L =~ ' [[:alnum:]-]\+ '
    return fugitive#buffer().repo().superglob(a:A)
  elseif a:A == ''
    return cmds
  else
    return filter(cmds,'v:val[0 : strlen(a:A)-1] ==# a:A')
  endif
endfunction "}}} }}}

let &cpo = s:savecpo
unlet s:savecpo

 " vim:fdm=marker
