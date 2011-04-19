"AUTHOR:   Greg Sexton <gregsexton@gmail.com>
"WEBSITE:  ???
"LICENSE:  Same terms as Vim itself (see :help license).
"NOTES:    Much of the credit for gitv goes to Tim Pope and the fugitive plugin
"          where this plugin either uses functionality directly or was inspired heavily.

"TODO: ack for 'gitk' should not exist.
"TODO: ensure this is uncommented
"if exists("g:loaded_gitv") || v:version < 700
  "finish
"endif
let g:loaded_gitv = 1

"configurable options:
"g:Gitv_CommitStep
"g:Gitv_OpenHorizontal

if !exists("g:Gitv_CommitStep")
    let g:Gitv_CommitStep = 70 "TODO: turn this into the window height.
endif

command! -nargs=* -bar -bang Gitv call s:OpenGitv(<q-args>, <bang>0)
cabbrev gitv Gitv

fu! Gitv_OpenGitCommand(command, windowCmd, ...) "{{{
    "returns 1 if command succeeded with output
    "optional arg is a flag, if present runs command verbatim

    "this function is not limited to script scope as is useful for running other commands.
    "e.g call Gitv_OpenGitCommand("diff --no-color", 'vnew') is useful for getting an overall git diff.

    if !a:0     "no extra args
        "switches to the buffer repository before running the command and switches back after.
        let dir = fugitive#extract_dir()
        if dir == ''
            echo "No git repository could be found."
            return 0
        endif
        let workingDir = fnamemodify(dir,':h')

        let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd ' : 'cd '
        let bufferDir = getcwd()
        try
            execute cd.'`=workingDir`'
            echo 'git --git-dir="' .dir. '" ' . a:command
            let finalCmd = 'git --git-dir="' .dir. '" ' . a:command
            let result = system(finalCmd)
        finally
            execute cd.'`=bufferDir`'
        endtry
    else
        let result = system(a:command)
    endif

    "let result = system('git ' . a:command)
    if result == ""
        echo "No output."
        return 0
    else
        if a:windowCmd == ''
            silent setlocal modifiable
            silent setlocal noreadonly
            1,$ d
        else
            exec a:windowCmd
        endif
        if !a:0
            let b:Git_Command = finalCmd
        else
            let b:Git_Command = a:command
        endif
        silent setlocal ft=git
        silent setlocal buftype=nofile
        silent setlocal nobuflisted
        silent setlocal noswapfile
        silent setlocal bufhidden=delete
        silent setlocal nonumber
        silent setlocal nowrap
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
endf "}}}
fu! s:OpenGitv(extraArgs, fileMode) "{{{
    if a:fileMode
        echom "File mode!"
    else
        call s:OpenBrowserMode(a:extraArgs)
    endif
endf "}}}
fu! s:OpenBrowserMode(extraArgs) "{{{
    silent Gtabedit HEAD

    if s:IsHorizontal()
        let direction = 'new gitv'
    else
        let direction = 'vnew gitv'
    endif

    if !s:LoadGitv(direction, 0, g:Gitv_CommitStep, a:extraArgs)
        return 0
    endif

    silent setlocal cursorline

    if s:IsHorizontal()
        silent command! -buffer -nargs=* -complete=customlist,fugitive#git_complete Git wincmd j|Git <args>|wincmd k|normal u
    else
        silent command! -buffer -nargs=* -complete=customlist,fugitive#git_complete Git wincmd l|Git <args>|wincmd h|normal u
    endif

    "open the first commit
    silent call s:OpenGitvCommit()
endf "}}}
fu! s:OpenPreviewMode(extraArgs) "{{{
endf "}}}
fu! s:LoadGitv(direction, reload, commitCount, extraArgs) "{{{
    let cmd = "log " . a:extraArgs . " --no-color --decorate=full --pretty=format:\"%d %s__SEP__%ar__SEP__%an__SEP__[%h]\" --graph -" . a:commitCount

    if a:reload
        let jumpTo = line('.') "this is for repositioning the cursor after reload
        if exists('b:Git_Command')
            "substitute in the new commit count
            let newcmd = substitute(b:Git_Command, " -\\d\\+$", " -" . a:commitCount, "")
            silent let res = Gitv_OpenGitCommand(newcmd, a:direction, 1)
        endif
    else
        silent let res = Gitv_OpenGitCommand(cmd, a:direction)
    endif

    if !res
        return 0
    endif

    silent set filetype=gitv
    let b:Gitv_CommitCount = a:commitCount
    let b:Gitv_ExtraArgs   = a:extraArgs
    silent setlocal modifiable
    silent setlocal noreadonly
    silent %s/refs\/tags\//t:/ge
    silent %s/refs\/remotes\//r:/ge
    silent %s/refs\/heads\///ge
    silent 1,$Tabularize /__SEP__/
    silent %s/__SEP__//g
    call append(line('$'), '-- Load More --')

    exec exists('jumpTo') ? jumpTo : '1'

    silent setlocal nomodifiable
    silent setlocal readonly

    "redefine some of the mappings made by Gitv_OpenGitCommand
    nmap <buffer> <silent> <cr> :call <SID>OpenGitvCommit()<cr>
    nmap <buffer> <silent> q :call <SID>CloseGitv()<CR>
    nmap <buffer> <silent> u :call <SID>LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs)<cr>
    nmap <buffer> <silent> co :call <SID>CheckOutGitvCommit()<cr>

    echom "Loaded up to " . a:commitCount . " commits."
    return 1
endf "}}}
fu! s:GetGitvSha() "{{{
    let l = getline('.')
    let sha = matchstr(l, "\\[\\zs[0-9a-f]\\{7}\\ze\\]$")
    return sha
endf "}}}
fu! s:GetGitvRefs() "{{{
    let l = getline('.')
    let refstr = matchstr(l, "^\\(\\(|\\|\\/\\|\\\\\\|\\*\\)\\s\\?\\)*\\s\\+(\\zs.\\{-}\\ze)")
    let refs = split(refstr, ', ')
    return refs
endf "}}}
fu! s:OpenGitvCommit() "{{{
    if getline('.') == "-- Load More --"
        call s:LoadGitv('', 1, b:Gitv_CommitCount+g:Gitv_CommitStep, b:Gitv_ExtraArgs)
        return
    endif
    let sha = s:GetGitvSha()
    if sha == ""
        return
    endif
    if s:IsHorizontal()
        wincmd j
    else
        wincmd l
    endif
    exec "Gedit " . sha
    if s:IsHorizontal()
        wincmd k
    else
        wincmd h
    endif
endf "}}}
fu! s:CheckOutGitvCommit() "{{{
    let allrefs = s:GetGitvRefs()
    let sha = s:GetGitvSha()
    if sha == ""
        return
    endif
    "remove remotes -- TODO: replace this with filter
    let refs = []
    for ref in allrefs
        if match(ref, "^r:") == -1
            let refs += [ref]
        endif
    endfor
    let refs += [sha]
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
    exec "Git checkout " . choice
endf "}}}
fu! s:IsHorizontal() "{{{
    return exists('g:Gitv_OpenHorizontal') && g:Gitv_OpenHorizontal == 1
endf "}}}
fu! s:CloseGitv() "{{{
    tabc
endfu "}}}

 " vim:fdm=marker
