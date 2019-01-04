"AUTHOR:     Greg Sexton <gregsexton@gmail.com>
"MAINTAINER: Roger Bongers <r.l.bongers@gmail.com>
"WEBSITE:    http://www.gregsexton.org/portfolio/gitv/
"LICENSE:    Same terms as Vim itself (see :help license).
"NOTES:      Much of the credit for gitv goes to Tim Pope and the fugitive plugin
"            where this plugin either uses functionality directly or was inspired heavily.

if exists("g:loaded_gitv") || v:version < 700
  finish
endif
let g:loaded_gitv = 1

let s:savecpo = &cpo
set cpo&vim

"configurable options:
"g:Gitv_CommitStep                - int
"g:Gitv_OpenHorizontal            - {0,1,'AUTO'}
"g:Gitv_WipeAllOnClose            - int
"g:Gitv_WrapLines                 - {0,1}
"g:Gitv_TruncateCommitSubjects    - {0,1}
"g:Gitv_OpenPreviewOnLaunch       - {0,1}
"g:Gitv_PromptToDeleteMergeBranch - {0,1}

if !exists("g:Gitv_CommitStep")
    let g:Gitv_CommitStep = &lines
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

if !exists('g:Gitv_PromptToDeleteMergeBranch')
    let g:Gitv_PromptToDeleteMergeBranch = 0
endif

if !exists('g:Gitv_CustomMappings')
    let g:Gitv_CustomMappings = {}
endif

if !exists('g:Gitv_DisableShellEscape')
    let g:Gitv_DisableShellEscape = 0
endif

if !exists('g:Gitv_DoNotMapCtrlKey')
    let g:Gitv_DoNotMapCtrlKey = 0
endif

if !exists('g:Gitv_PreviewOptions')
    let g:Gitv_PreviewOptions = ''
endif

if !exists('g:Gitv_QuietBisect')
    let g:Gitv_QuietBisect = 0
endif

" create a temporary file for working
let s:workingFile = tempname()

"this counts up each time gitv is opened to ensure a unique file name
let g:Gitv_InstanceCounter = 0

let s:localUncommitedMsg = 'Local uncommitted changes, not checked in to index.'
let s:localCommitedMsg   = 'Local changes checked in to index but not committed.'

let s:pendingRebaseMsg = 'View pending rebase instructions'
let s:rebaseMsg = 'Edit rebase todo'

command! -nargs=* -range -bang -complete=custom,s:CompleteGitv Gitv call s:OpenGitv(s:EscapeGitvArgs(<q-args>), <bang>0, <line1>, <line2>)
cabbrev gitv <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Gitv' : 'gitv')<CR>

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
            1,$ d _
        else
            let goBackTo       = winnr()
            let dir            = fugitive#repo().dir()
            let workingDir     = fugitive#repo().tree()
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
        if exists('+relativenumber')
            silent setlocal norelativenumber
        endif
        if g:Gitv_WrapLines
            silent setlocal wrap
        else
            silent setlocal nowrap
        endif
        silent setlocal fdm=syntax
        nnoremap <buffer> <silent> q :q!<CR>
        nnoremap <buffer> <silent> u :if exists('b:Git_Command')<bar>call Gitv_OpenGitCommand(b:Git_Command, '', 1)<bar>endif<cr>
        call append(0, split(result, '\n')) "system converts eols to \n regardless of os.
        silent setlocal nomodifiable
        silent setlocal readonly
        1
        return 1
    endif
endf "}}}
fu! Gitv_GetDebugInfo() "{{{
    if has('clipboard')
        redir @+
    endif

    echo '## Gitv debug output'
    echo ''

    echo '### Basic information'
    echo ''
    echo '```'
    echo 'Version: 1.3.1.22'
    echo ''
    echo strftime('%c')
    echo '```'
    echo ''

    echo '### Settings'
    echo ''
    echo '```'
    set
    echo '```'
    echo ''

    echo '### Vim version'
    echo ''
    echo '```'
    version
    echo '```'
    echo ''

    echo '### Git output'
    echo ''
    echo '```'

    try
        echo '$ git --version'
        echo s:RunCommandRelativeToGitRepo('git --version')[0]
        echo '$ git status'
        echo s:RunCommandRelativeToGitRepo('git status')[0]
        echo '$ git remote --verbose'
        echo s:RunCommandRelativeToGitRepo('git remote --verbose')[0]
    catch
        echo 'Gitv_GetDebugInfo exception:'
        echo v:exception
    endtry

    echo '```'
    echo ''

    echo '### Fugitive version'
    echo ''
    echo '```'

    try
        let filename = s:GetFugitiveInfo()[1]
        " Make sure redirection is still set up
        if has('clipboard')
            redir @+
        endif
        for line in readfile(filename)
            if line =~ 'Version:' || line =~ 'GetLatestVimScripts:'
                echo line
            endif
        endfor
    catch
        echo 'Gitv_GetDebugInfo exception:'
        echo v:exception
    endtry

    echo '```'
    echo ''

    redir END

    if has('clipboard')
        echo 'Debug information has been copied to your clipboard. Please attach this information to your submitted issue.'
    else
        echo 'Please copy the contents above and add them to your submitted issue.'
    endif
endf "}}} }}}
"General Git Functions: "{{{
fu! s:RunGitCommand(command, verbatim) "{{{
    "if verbatim returns result of system command, else
    "switches to the buffer repository before running the command and switches back after.
    if !a:verbatim
        "switches to the buffer repository before running the command and switches back after.
        let cmd                = fugitive#repo().git_command() .' '. a:command
        let [result, finalCmd] = s:RunCommandRelativeToGitRepo(cmd)
    else
        let result   = system(a:command)
        let finalCmd = a:command
    endif
    return [result, finalCmd]
endfu "}}}
fu! s:RunCommandRelativeToGitRepo(command) abort "{{{
    " Runs the command verbatim but first changing to the root git dir.
    " Input commands should include a --git-dir argument to git (see
    " fugitive#repo().git_command()).
    let workingDir = fugitive#repo().tree()

    let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd ' : 'cd '
    let bufferDir = getcwd()
    try
        execute cd.'`=workingDir`'
        let result   = system(a:command)
    finally
        execute cd.'`=bufferDir`'
    endtry
    return [result, a:command]
endfu "}}} }}}
"Open And Update Gitv:"{{{
fu! s:SanitizeReservedArgs(extraArgs) "{{{
    let sanitizedArgs = a:extraArgs
    if sanitizedArgs[0] =~ "[\"']" && sanitizedArgs[:-1] =~ "[\"']"
        let sanitizedArgs = sanitizedArgs[1:-2]
    endif
    " store bisect
    if match(sanitizedArgs, ' --bisect') >= 0
        let sanitizedArgs = substitute(sanitizedArgs, ' --bisect', '', 'g')
        if s:BisectHasStarted()
            let b:Gitv_Bisecting = 1
        endif
    endif
    " store files
    let selectedFiles = []
    let splitArgs = split(sanitizedArgs, ' ')
    let index = len(splitArgs)
    let root = fugitive#repo().tree().'/'
    while index
        let index -= 1
        let path = splitArgs[index]
        if !empty(globpath('.', path))
            " transform the path relative to the git directory
            let path = fnamemodify(path, ':p')
            let splitPath = split(path, root)
            if splitPath[0] == path
                echoerr "Not in git repo:" path
                break
            endif
            " join the relroot back in case we split more than one off
            let path = join(splitPath, root)
            let selectedFiles += [path]
        else
            break
        endif
    endwhile
    let selectedFiles = sort(selectedFiles)
    return [join(splitArgs[0:-len(selectedFiles) - 1], ' '), join(selectedFiles, ' ')]
endfu "}}}
fu! s:ReapplyReservedArgs(extraArgs) "{{{
    let options = a:extraArgs[0]
    if s:RebaseIsEnabled()
        return [options, '']
    endif
    if s:BisectIsEnabled()
        if !s:IsBisectingCurrentFiles()
            echoerr "Not bisecting specified files."
            let b:Gitv_Bisecting = 0
        else
            let options .= " --bisect"
            let options = s:FilterArgs(options, ['--all', '--first-parent'])
        endif
    endif
    return [options, a:extraArgs[1]]
endfu "}}}
fu! s:EscapeGitvArgs(extraArgs) "{{{
    " TODO: test whether shellescape is really needed on windows.
    if g:Gitv_DisableShellEscape == 0
        return shellescape(a:extraArgs)
    else
        return a:extraArgs
    endif
endfu "}}}
fu! s:OpenGitv(extraArgs, fileMode, rangeStart, rangeEnd) "{{{
    if !exists('s:fugitiveSid')
        let s:fugitiveSid = s:GetFugitiveSid()
    endif
    let sanitizedArgs = s:SanitizeReservedArgs(a:extraArgs)
    let g:Gitv_InstanceCounter += 1
    if !s:IsCompatible() "this outputs specific errors
        return
    endif
    try
        if a:fileMode
            call s:OpenFileMode(sanitizedArgs, a:rangeStart, a:rangeEnd)
        else
            call s:OpenBrowserMode(sanitizedArgs)
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
fu! s:CompleteGitv(arglead, cmdline, pos) "{{{
    if match( a:arglead, '^-' ) >= 0
        return  "\n--after\n--all-match\n--ancestry-path\n--author-date-order"
                \ . "\n--author=\n--author=\n--before=\n--bisect\n--boundary"
                \ . "\n--branches\n--cherry-mark\n--cherry-pick\n--committer="
                \ . "\n--date-order\n--dense\n--exclude=\n--first-parent"
                \ . "\n--fixed-strings\n--follow\n--glob\n--grep-reflog"
                \ . "\n--grep=\n--max-age=\n--max-count=\n--merges\n--no-merges"
                \ . "\n--min-age=\n--min-parents=\n--not\n--pickaxe-all"
                \ . "\n--pickaxe-regex\n--regexp-ignore-case\n--remotes"
                \ . "\n--remove-empty\n--since=\n--skip\n--tags\n--topo-order"
                \ . "\n--until=\n--use-mailmap"
    else
        if match(a:arglead, '\/$') >= 0
            let paths = "\n".globpath(a:arglead, '*')
        else
            let paths = "\n".glob(a:arglead.'*')
        endif

        let refs = fugitive#repo().git_chomp('rev-parse', '--symbolic', '--branches', '--tags', '--remotes')
        let refs .= "\nHEAD\nFETCH_HEAD\nORIG_HEAD"

        " Complete ref names preceded by a ^ or anything followed by 2-3 dots
        let prefix = matchstr( a:arglead, '\v^(\^|.*\.\.\.?)' )
        if prefix == ''
            return refs.paths
        else
            return substitute( refs, "\\v(^|\n)\\zs", prefix, 'g' ).paths
        endif
endf "}}}
fu! s:OpenBrowserMode(extraArgs) "{{{
    "this throws an exception if not a git repo which is caught immediately
    silent Gtabedit HEAD:

    if s:IsHorizontal()
        let direction = 'new gitv'.'-'.g:Gitv_InstanceCounter
    else
        let direction = 'vnew gitv'.'-'.g:Gitv_InstanceCounter
    endif
    if !s:LoadGitv(direction, 0, g:Gitv_CommitStep, a:extraArgs, '', [])
        return 0
    endif
    call s:SetupBufferCommands(0)
    let b:Gitv_RebaseInstructions = {}
    "open the first commit
    if g:Gitv_OpenPreviewOnLaunch
        silent call s:OpenGitvCommit("Gedit", 0)
    else
        call s:MoveIntoPreviewAndExecute('bdelete', 0)
    endif
endf "}}}
fu! s:OpenFileMode(extraArgs, rangeStart, rangeEnd) "{{{
    let relPath = fugitive#Path(@%, a:0 ? a:1 : '')
    pclose!
    let range = a:rangeStart != a:rangeEnd ? s:GetRegexRange(a:rangeStart, a:rangeEnd) : []
    if !s:LoadGitv(&previewheight . "new gitv".'-'.g:Gitv_InstanceCounter, 0, g:Gitv_CommitStep, a:extraArgs, relPath, range)
        return 0
    endif
    set previewwindow
    set winfixheight
    let b:Gitv_FileMode = 1
    let b:Gitv_FileModeRelPath = relPath
    let b:Gitv_FileModeRange = range
    call s:SetupBufferCommands(1)
endf "}}}
fu! s:LoadGitv(direction, reload, commitCount, extraArgs, filePath, range) "{{{
    call s:RebaseUpdate()
    call s:BisectUpdate()

    if a:reload
        let jumpTo = line('.') "this is for repositioning the cursor after reload
    endif

    "precondition: a:range should be of the form [a, b] or []
    "   where a,b are integers && a<b
    if !s:ConstructAndExecuteCmd(a:direction, a:commitCount, a:extraArgs, a:filePath, a:range)
        return 0
    endif
    call s:SetupBuffer(a:commitCount, a:extraArgs, a:filePath, a:range)
    exec exists('jumpTo') ? jumpTo : '1'
    call s:SetupMappings() "redefines some of the mappings made by Gitv_OpenGitCommand
    call s:ResizeWindow(a:filePath!='')

    echom "Loaded up to " . a:commitCount . " commits."
    return 1
endf "}}}
fu! s:FilterArgs(args, sanitize) "{{{
    let newArgs = a:args
    for arg in a:sanitize
        let newArgs = substitute(newArgs, '\( \|^\)' . arg, '', 'g')
    endfor
    return newArgs
endf "}}}
fu! s:ToggleArg(args, toggle) "{{{
    if matchstr(a:args[0], a:toggle) == ''
      let NewArgs = a:args[0] . ' ' . a:toggle
    else
      let NewArgs = substitute(a:args[0], '\( \|^\)' . a:toggle, '', '')
    endif
    let b:Gitv_ExtraArgs = [NewArgs, a:args[1]]
    return [NewArgs, a:args[1]]
endf "}}}
fu! s:ConstructAndExecuteCmd(direction, commitCount, extraArgs, filePath, range) "{{{
    if a:range == [] "no range, setup and execute the command
        let extraArgs = s:ReapplyReservedArgs(a:extraArgs)
        let cmd  = "log " 
        let cmd .= " --no-color --decorate=full --pretty=format:\"%d__START__ %s__SEP__%ar__SEP__%an__SEP__[%h]\" --graph -"
        let cmd .= a:commitCount
        let cmd .= " " . extraArgs[0]
        if a:filePath != ''
            let cmd .= ' -- ' . a:filePath
        elseif extraArgs[1] != ''
            let cmd .= ' -- ' . extraArgs[1]
        endif
        let g:cmd = cmd
        silent let res = Gitv_OpenGitCommand(cmd, a:direction)
        return res
    else "range applies, setup a trivial buffer and then modify it with custom logic
        let cmd = "--version" "arbitrary command intended to setup the buffer
                              "and act as a check everything is ok
        let g:cmd = cmd
        silent let res = Gitv_OpenGitCommand(cmd, a:direction)
        if !res | return res | endif
        silent let res = s:ConstructRangeBuffer(a:commitCount, a:extraArgs, a:filePath, a:range)
        return res
    endif
endf "}}}
"Range Commands: {{{
fu! s:ConstructRangeBuffer(commitCount, extraArgs, filePath, range) "{{{
    silent setlocal modifiable
    silent setlocal noreadonly
    %delete

    "necessary as order is important; can't just iterate over keys(slices)
    let extraArgs = s:ReapplyReservedArgs(a:extraArgs)
    let hashCmd       = "log " . extraArgs[0]
    let hashCmd      .= " --no-color --pretty=format:%H -".a:commitCount." -- " . a:filePath
    let [result, cmd] = s:RunGitCommand(hashCmd, 0)
    let hashes        = split(result, '\n')

    let slices = s:GetFileSlices(a:range, a:filePath, a:commitCount, a:extraArgs)

    if s:AllSlicesBlank(slices)
        call append(0, 'No commits matched the range. Try altering the search.')
    else
        let modHashes = []
        for i in range(len(hashes))
            let hash1 = hashes[i]
            let hash2 = get(hashes, i+1, "")
            if (hash2 == "" && has_key(slices, hash1)) || s:CompareFileAtCommits(slices, hash1, hash2)
                let modHashes = add(modHashes, hash1)
            endif
        endfor

        let output = s:GetFinalOutputForHashes(modHashes)
        call append(0, output)
    endif

    silent setlocal nomodifiable
    silent setlocal readonly
    return 1
endf "}}}
fu! s:GetFileSlices(range, filePath, commitCount, extraArgs) "{{{
    "this returns a dictionary, indexed by commit sha, of all slices of range lines of filePath
    "NOTE: this could get massive for a large repo and large range
    let range     = a:range[0] . ',' . a:range[1]
    let range     = substitute(range, "'", "'\\\\''", 'g') "force unix style escaping even on windows
    let git       = fugitive#repo().git_command()
    let sliceCmd  = "for hash in `".git." log " . a:extraArgs[0]
    let sliceCmd .= " --no-color --pretty=format:%H -".a:commitCount." -- " . a:filePath . '`; '
    let sliceCmd .= "do "
    let sliceCmd .= 'echo "****${hash}"; '
    let sliceCmd .= git." --no-pager blame -s -L '" . range . "' ${hash} " . a:filePath . "; "
    let sliceCmd .= "done"
    let finalCmd  = "bash -c " . shellescape(sliceCmd)

    let [result, cmd] = s:RunCommandRelativeToGitRepo(finalCmd)
    let slicesLst     = split(result, '\(^\|\n\)\zs\*\{4}')
    let slices        = {}

    for slice in slicesLst
        let key = matchstr(slice, '^.\{-}\ze\n')
        let val = matchstr(slice, '\n\zs.*')
        if val !~? '^fatal: .*$'
            "remove the commit sha and line number to stop them affecting the comparisons
            let lines = split(val, '\n')
            call map(lines, "matchstr(v:val, '\\x\\{-} \\d\\+) \\zs.*')")
            let finalVal = join(lines)
            let slices[key] = finalVal
        endif
    endfor

    return slices
endfu "}}}
fu! s:AllSlicesBlank(slices) "{{{
    for i in keys(a:slices)
        if a:slices[i] != ''
            return 0
        endif
    endfor
    return 1
endfu "}}}
fu! s:CompareFileAtCommits(slices, c1sha, c2sha) "{{{
    "returns 1 if lineRange for filePath in commits: c1sha and c2sha are different
    "else returns 0
    if has_key(a:slices, a:c1sha) && !has_key(a:slices, a:c2sha)
        return 1
    endif
    if has_key(a:slices, a:c1sha) && has_key(a:slices, a:c2sha)
        return a:slices[a:c1sha] != a:slices[a:c2sha]
    else
        return 0
    endif
endfu "}}}
fu! s:GetFinalOutputForHashes(hashes) "{{{
    if len(a:hashes) > 0
        let extraArgs = s:ReapplyReservedArgs(['', ''])
        let git       = fugitive#repo().git_command()
        let cmd       = 'for hash in ' . join(a:hashes, " ") . '; '
        let cmd      .= "do "
        let cmd      .= git.' log'
        let cmd      .= extraArgs[0]
        let cmd      .=' --no-color --decorate=full --pretty=format:"%d__START__ %s__SEP__%ar__SEP__%an__SEP__[%h]%n" --graph -1 ${hash}; '
        let cmd      .= 'done'
        let finalCmd  = "bash -c " . shellescape(cmd)

        let [result, cmd] = s:RunCommandRelativeToGitRepo(finalCmd)
        return split(result, '\n')
    else
        return ""
    endif
endfu "}}}
fu! s:GetRegexRange(rangeStart, rangeEnd) "{{{
    let rangeS = getline(a:rangeStart)
    let rangeS = escape(rangeS, '.^$*\/[]')
    let rangeS = matchstr(rangeS, '\v^\s*\zs.{-}\ze\s*$') "trim whitespace
    let rangeE = getline(a:rangeEnd)
    let rangeE = escape(rangeE, '.^$*\/[]')
    let rangeE = matchstr(rangeE, '\v^\s*\zs.{-}\ze\s*$') "trim whitespace
    let rangeS = rangeS =~ '^\s*$' ? '^[:blank:]*$' : rangeS
    let rangeE = rangeE =~ '^\s*$' ? '^[:blank:]*$' : rangeE
    return ['/'.rangeS.'/', '/'.rangeE.'/']
endfu "}}} }}}
fu! s:SetupBuffer(commitCount, extraArgs, filePath, range) "{{{
    silent set filetype=gitv
    let b:Gitv_CommitCount = a:commitCount
    let b:Gitv_ExtraArgs   = a:extraArgs
    silent setlocal modifiable
    silent setlocal noreadonly
    silent %s/refs\/tags\//t:/ge
    silent %s/refs\/remotes\//r:/ge
    silent %s/refs\/heads\///ge
    call s:AddLoadMore()
    call s:AddLocalNodes(a:filePath)
    call s:AddFileModeSpecific(a:filePath, a:range, a:commitCount)
    call s:AddRebaseMessage(a:filePath)

    " run any autocmds the user may have defined to hook in here
    silent doautocmd User GitvSetupBuffer

    silent call s:InsertRebaseInstructions()
    silent %call s:Align("__SEP__", a:filePath)
    silent %s/\s\+$//e
    silent setlocal nomodifiable
    silent setlocal readonly
    silent setlocal cursorline
endf "}}}
fu! s:InsertRebaseInstructions() "{{{
    if s:RebaseHasInstructions()
        for key in keys(b:Gitv_RebaseInstructions)
            let search = '__START__\ze.*\['.key.'\]$'
            let replace = ' ['.b:Gitv_RebaseInstructions[key].instruction
            if exists('b:Gitv_RebaseInstructions[key].cmd')
                let replace .= 'x'
            endif
            let replace .= ']'
            exec '%s/'.search.'/'.replace
        endfor
    endif
    %s/__START__//
endf "}}}
fu! s:CleanupRebasePreview() "{{{
    if &syntax == 'gitrebase'
        bdelete
    endif
endf "}}}
fu! s:AddRebaseMessage(filePath) "{{{
    if a:filePath != ''
        return
    endif
    if s:RebaseHasInstructions()
        call append(0, '= '.s:pendingRebaseMsg)
    elseif s:RebaseIsEnabled()
        call append(0, '= '.s:rebaseMsg)
    else
        " TODO: this will fail if there's no preview window
        call s:MoveIntoPreviewAndExecute('call s:CleanupRebasePreview()', 0)
    endif
endf "}}}
fu! s:AddLocalNodes(filePath) "{{{
    let suffix = a:filePath == '' ? '' : ' -- '.a:filePath
    let gitCmd = "diff --no-color" . suffix
    let [result, cmd] = s:RunGitCommand(gitCmd, 0)
    let headLine = search('^\(\(|\|\/\|\\\|\*\)\s\?\)*\s*([^)]*HEAD', 'cnw')
    let headLine = headLine == 0 ? 1 : headLine
    if result != ""
        let line = s:AlignWithRefs(headLine, s:localUncommitedMsg)
        call append(headLine-1, substitute(line, '*', '=', ''))
        let headLine += 1
    endif
    let gitCmd = "diff --no-color --cached" . suffix
    let [result, cmd] = s:RunGitCommand(gitCmd, 0)
    if result != ""
        let line = s:AlignWithRefs(headLine, s:localCommitedMsg)
        call append(headLine-1, substitute(line, '*', '+', ''))
    endif
endfu
fu! s:AlignWithRefs(targetLine, targetStr)
    "returns the targetStr prefixed with enough whitespace to align with
    "the first asterisk on targetLine
    if a:targetLine == 0
        return '*  '.a:targetStr
    endif
    let line = getline(a:targetLine)
    let idx = stridx(line, '(')
    if idx == -1
        return '*  '.a:targetStr
    endif
    return strpart(line, 0, idx) . a:targetStr
endfu "}}}
fu! s:AddLoadMore() "{{{
    call append(line('$'), '-- Load More --')
endfu "}}}
fu! s:AddFileModeSpecific(filePath, range, commitCount) "{{{
    if a:filePath != ''
        call append(0, '-- ['.a:filePath.'] --')
        if a:range != []
            call append(1, '-- Showing (up to '.a:commitCount.') commits affecting lines in the range:')
            call append(2, '-- ' . a:range[0])
            call append(3, '-- ' . a:range[1])
        endif
    endif
endfu "}}}
"Mapping: "{{{
fu! s:SetDefaultMappings() "{{{
    " creates the script-scoped dictionary of mapping descriptors
    " the dictionary will optionally include ctrl based commands
    " sets s:defaultMappings to the dictionary
    let s:defaultMappings = {}

    " convenience
    let s:defaultMappings.quit = {
        \'cmd': ':<C-U>call <SID>CloseGitv()<cr>', 'bindings': 'q'
    \}
    let s:defaultMappings.update = {
        \'cmd': ':<C-U>call <SID>LoadGitv("", 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, <SID>GetRelativeFilePath(), <SID>GetRange())<cr>',
        \'bindings': 'u'
    \}
    let s:defaultMappings.toggleAll = {
        \'cmd': ':<C-U>call <SID>LoadGitv("", 0, b:Gitv_CommitCount, <SID>ToggleArg(b:Gitv_ExtraArgs, "--all"), <SID>GetRelativeFilePath(), <SID>GetRange())<cr>',
        \'bindings': 'a'
    \}

    " movement
    let s:defaultMappings.nextBranch = {
        \'cmd': ':call <SID>JumpToBranch(0)<cr>',
        \'bindings': 'x'
    \}
    let s:defaultMappings.prevBranch = {
        \'cmd': ':call <SID>JumpToBranch(1)<cr>',
        \'bindings': 'X'
    \}
    let s:defaultMappings.nextRef = {
        \'cmd': ':call <SID>JumpToRef(0)<cr>',
        \'bindings': 'r'
    \}
    let s:defaultMappings.prevRef = {
        \'cmd': ':call <SID>JumpToRef(1)<cr>',
        \'bindings': 'R'
    \}
    let s:defaultMappings.head = {
        \'cmd': ':<C-U>call <SID>JumpToHead()<cr>',
        \'bindings': 'P'
    \}
    let s:defaultMappings.parent = {
        \'cmd': ':<C-U>call <SID>JumpToParent()<cr>',
        \'bindings': 'p'
    \}
    let s:defaultMappings.toggleWindow = {
        \'cmd': ':<C-U>call <SID>SwitchBetweenWindows()<cr>',
        \'bindings': 'gw'
    \}

    " viewing commits
    let s:defaultMappings.editCommit = {
        \'cmd': ':<C-U>call <SID>OpenGitvCommit("Gedit", 0)<cr>',
        \'bindings': [
            \'<cr>', { 'keys': '<LeftMouse>', 'prefix': '<LeftMouse>' }
        \],
    \}
    " <Plug>(gitv-*) are fuzzyfinder style keymappings
    let s:defaultMappings.splitCommit = {
        \'cmd': ':<C-U>call <SID>OpenGitvCommit("Gsplit", 0)<cr>',
        \'bindings': 'o',
        \'permanentBindings': '<Plug>(gitv-split)'
    \}
    let s:defaultMappings.tabeCommit = {
        \'cmd': ':<C-U>call <SID>OpenGitvCommit("Gtabedit", 0)<cr>',
        \'bindings': 'O' ,
        \'permanentBindings': '<Plug>(gitv-tabedit)'
    \}
    let s:defaultMappings.vertSplitCommit = {
        \'cmd': ':<C-U>call <SID>OpenGitvCommit("Gvsplit", 0)<cr>',
        \'bindings': 's',
        \'permanentBindings': '<Plug>(gitv-vsplit)'
    \}
    let s:defaultMappings.prevCommit = {
        \'cmd': ':<C-U>call <SID>JumpToCommit(0)<cr>',
        \'bindings': 'J',
        \'permanentBindings': '<Plug>(gitv-previous-commit)'
    \}
    let s:defaultMappings.nextCommit = {
        \'cmd': ':<C-U>call <SID>JumpToCommit(1)<cr>',
        \'bindings': 'K',
        \'permanentBindings': '<Plug>(gitv-next-commit)'
    \}
    " force opening the fugitive buffer for the commit
    let s:defaultMappings.editCommitDetails = {
        \'cmd': ':<C-U>call <SID>OpenGitvCommit("Gedit", 1)<cr>',
        \'bindings': 'i',
        \'permanentBindings': '<Plug>(gitv-edit)'
    \}
    let s:defaultMappings.diff = {
        \'cmd': ':<C-U>call <SID>DiffGitvCommit()<cr>',
        \'bindings': 'D'
    \}
    let s:defaultMappings.vdiff = {
        \'mapCmd': 'vnoremap',
        \'cmd': ':call <SID>DiffGitvCommit()<cr>',
        \'bindings': 'D'
    \}
    let s:defaultMappings.stat = {
        \'cmd': ':<C-U>call <SID>StatGitvCommit()<cr>',
        \'bindings': 'S'
    \}
    let s:defaultMappings.vstat = {
        \'mapCmd': 'vnoremap',
        \'cmd': ':call <SID>StatGitvCommit()<cr>',
        \'bindings': 'S'
    \}

    " general git commands
    let s:defaultMappings.checkout = {
        \'cmd': ':<C-U>call <SID>CheckOutGitvCommit()<cr>', 'bindings': 'co'
    \}
    let s:defaultMappings.merge = {
        \'cmd': ':<C-U>call <SID>MergeToCurrent()<cr>', 'bindings': '<leader>m'
    \}
    let s:defaultMappings.vmerge = {
        \'mapCmd': 'vnoremap',
        \'cmd': ':call <SID>MergeBranches()<cr>',
        \'bindings': 'm'
    \}
    let s:defaultMappings.cherryPick = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>CherryPick()<cr>',
        \'bindings': 'cp'
    \}
    let s:defaultMappings.vcherryPick = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>CherryPick()<cr>',
        \'bindings': 'cp'
    \}
    let s:defaultMappings.reset = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>ResetBranch("--mixed")<cr>',
        \'bindings': 'rb'
    \}
    let s:defaultMappings.vreset = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>ResetBranch("--mixed")<cr>',
        \'bindings': 'rb'
    \}
    let s:defaultMappings.resetSoft = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>ResetBranch("--soft")<cr>',
        \'bindings': 'rbs'
    \}
    let s:defaultMappings.vresetSoft = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>ResetBranch("--soft")<cr>',
        \'bindings': 'rbs'
    \}
    let s:defaultMappings.resetHard = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>ResetBranch("--hard")<cr>',
        \'bindings': 'rbh'
    \}
    let s:defaultMappings.vresetHard = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>ResetBranch("--hard")<cr>',
        \'bindings': 'rbh'
    \}
    let s:defaultMappings.revert = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>Revert()<cr>',
        \'bindings': 'rev'
    \}
    let s:defaultMappings.vrevert = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>Revert()<cr>',
        \'bindings': 'rev'
    \}
    let s:defaultMappings.delete = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>DeleteRef()<cr>',
        \'bindings': 'd'
    \}
    let s:defaultMappings.vdelete = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>DeleteRef()<cr>',
        \'bindings': 'd'
    \}

    " rebasing
    let s:defaultMappings.rebase = {
        \'cmd': ':<C-U>call <SID>Rebase()<cr>',
        \'bindings': 'grr'
    \}
    let s:defaultMappings.vrebase = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>Rebase()<cr>',
        \'bindings': 'grr'
    \}
    let s:defaultMappings.rebasePick = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("p")<cr>',
        \'bindings': 'grP'
    \}
    let s:defaultMappings.vrebasePick = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("p")<cr>',
        \'bindings': 'grP'
    \}
    let s:defaultMappings.rebaseReword = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("r")<cr>',
        \'bindings': 'grR'
    \}
    let s:defaultMappings.vrebaseReword = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("r")<cr>',
        \'bindings': 'grR'
    \}
    let s:defaultMappings.rebaseMarkEdit = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("e")<cr>',
        \'bindings': 'grE'
    \}
    let s:defaultMappings.vrebaseMarkEdit = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("e")<cr>',
        \'bindings': 'grE'
    \}
    let s:defaultMappings.rebaseSquash = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("s")<cr>',
        \'bindings': 'grS'
    \}
    let s:defaultMappings.vrebaseSquash = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("s")<cr>',
        \'bindings': 'grS'
    \}
    let s:defaultMappings.rebaseFixup = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("f")<cr>',
        \'bindings': 'grF'
    \}
    let s:defaultMappings.vrebaseFixup = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("f")<cr>',
        \'bindings': 'grF'
    \}
    let s:defaultMappings.rebaseExec = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("x")<cr>',
        \'bindings': 'grX'
    \}
    let s:defaultMappings.vrebaseExec = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("x")<cr>',
        \'bindings': 'grX'
    \}
    let s:defaultMappings.rebaseDrop = {
        \'cmd': ':<C-U>call <SID>RebaseSetInstruction("d")<cr>',
        \'bindings': 'grD'
    \}
    let s:defaultMappings.vrebaseDrop = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseSetInstruction("d")<cr>',
        \'bindings': 'grD'
    \}
    let s:defaultMappings.rebaseAbort = {
        \'cmd': ':<C-U>call <SID>RebaseAbort()<cr>',
        \'bindings': 'gra'
    \}
    let s:defaultMappings.rebaseToggle = {
        \'cmd': ':<C-U>call <SID>RebaseToggle()<cr>',
        \'bindings': 'grs'
    \}
    let s:defaultMappings.vrebaseToggle = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>RebaseToggle()<cr>',
        \'bindings': 'grs'
    \}
    let s:defaultMappings.rebaseSkip = {
        \'cmd': ':call <SID>RebaseSkip()<cr>',
        \'bindings': 'grn'
    \}
    let s:defaultMappings.rebaseContinue = {
        \'cmd': ':<C-U>call <SID>RebaseContinue()<cr>',
        \'bindings': 'grc'
    \}

    " bisecting
    let s:defaultMappings.bisectStart = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>BisectStart("n")<cr>',
        \'bindings': 'gbs'
    \}
    let s:defaultMappings.vbisectStart = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>BisectStart("v")<cr>',
        \'bindings': 'gbs'
    \}
    let s:defaultMappings.bisectGood = {
        \'mapCmd': 'nmap',
        \'cmd': ':call <SID>BisectGoodBad("good")<cr>',
        \'bindings': 'gbg'
    \}
    let s:defaultMappings.vbisectGood = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>BisectGoodBad("good")<cr>',
        \'bindings': 'gbg'
    \}
    let s:defaultMappings.bisectBad = {
        \'mapCmd': 'nmap',
        \'cmd': ':call <SID>BisectGoodBad("bad")<cr>',
        \'bindings': 'gbb'
    \}
    let s:defaultMappings.vbisectBad = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>BisectGoodBad("bad")<cr>',
        \'bindings': 'gbb'
    \}
    let s:defaultMappings.bisectSkip = {
        \'mapCmd': 'nmap',
        \'cmd': ':call <SID>BisectSkip("n")<cr>',
        \'bindings': 'gbn'
    \}
    let s:defaultMappings.vbisectSkip = {
        \'mapCmd': 'vmap',
        \'cmd': ':call <SID>BisectSkip("v")<cr>',
        \'bindings': 'gbn'
    \}
    let s:defaultMappings.bisectReset = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>BisectReset()<cr>',
        \'bindings': 'gbr'
    \}
    let s:defaultMappings.bisectLog = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>BisectLog()<cr>',
        \'bindings': 'gbl'
    \}
    let s:defaultMappings.bisectReplay = {
        \'mapCmd': 'nmap',
        \'cmd': ':<C-U>call <SID>BisectReplay()<cr>',
        \'bindings': 'gbp'
    \}

    " misc
    let s:defaultMappings.git = {
        \'mapOpts': '<buffer>',
        \'cmd': ':Git<space>',
        \'bindings': 'git'
    \}
    " yank the commit hash
    if has('mac') || !has('unix') || has('xterm_clipboard')
        let s:defaultMappings.yank = {
            \'cmd': "m'$F[w\"+yw`'",
            \'bindings': 'yc'
        \}
    else
        let s:defaultMappings.yank = {
            \'cmd': "m'$F[wyw`'",
            \'bindings': 'yc'
        \}
    endif

    " bindings which use ctrl
    if g:Gitv_DoNotMapCtrlKey != 1
        let s:defaultMappings.ctrlPreviousCommit = {
            \'mapCmd': 'nmap',
            \'cmd': '<Plug>(gitv-previous-commit)',
            \'preventCustomBindings': 1,
            \'bindings': '<C-n>'
        \}
        let s:defaultMappings.ctrlNextCommit = {
            \'mapCmd': 'nmap',
            \'cmd': '<Plug>(gitv-next-commit)',
            \'preventCustomBindings': 1,
            \'bindings': '<C-p>'
        \}
        let s:defaultMappings.ctrlEdit = {
            \'mapCmd': 'nmap',
            \'cmd': '<Plug>(gitv-edit)',
            \'preventCustomBindings': 1,
            \'bindings': '<c-cr>'
        \}
        let s:defaultMappings.ctrlSplit = {
            \'mapCmd': 'nmap',
            \'cmd': '<Plug>(gitv-split)',
            \'preventCustomBindings': 1,
            \'bindings': '<c-j>'
        \}
        let s:defaultMappings.ctrlVsplit = {
            \'mapCmd': 'nmap',
            \'cmd': '<Plug>(gitv-vsplit)',
            \'preventCustomBindings': 1,
            \'bindings': '<c-k>'
        \}
        let s:defaultMappings.ctrlTabe = {
            \'mapCmd': 'nmap',
            \'cmd': '<Plug>(gitv-tabedit)',
            \'preventCustomBindings': 1,
            \'bindings': '<c-l>'
        \}
    endif
endf "}}}
fu! s:NormalCmd(mapId, mappings) "{{{
    " Normal commands can sometimes be invoked after git commands with output
    " This means we may have to move out of the terminal to execute them
    let terminalStatus = s:MoveOutOfNvimTerminal()
    let bindings = s:GetBindings(a:mapId, a:mappings)
    exec 'normal '.bindings[0].keys
    call s:MoveIntoNvimTerminal(terminalStatus)
endfu "}}}
fu! s:TransformBindings(bindings) "{{{
    " a:bindings can be a string or list of (in)complete binding descriptors
    " a list of complete binding descriptors will be returned
    " a complete binding object is a binding object with all possible fields
    if type(a:bindings) != 3 " list
        let bindings = [a:bindings]
    else
        let bindings = a:bindings
    endif
    let newBindings = []
    for binding in bindings
        if type(binding) != 4 " dictionary
            let newBinding = { 'keys': binding }
        else
            let newBinding = binding
        endif
        if !exists('newBinding.prefix')
            let newBinding.prefix = ''
        endif
        call add(newBindings, newBinding)
        unlet binding
    endfor
    return newBindings
endf "}}}
fu! s:GetBindings(mapId, mappings) "{{{
    " returns a list of complete binding objects based on customs/defaults
    " does not return custom bindings for descriptors with preventCustomBindings
    " always includes permanentBindings for an object
    let defaults = a:mappings[a:mapId]
    if exists('defaults.permanentBindings')
        let permanentBindings = s:TransformBindings(defaults.permanentBindings)
    else
        let permanentBindings = []
    endif
    if !exists('g:Gitv_CustomMappings[a:mapId]')
        let bindings = defaults.bindings
    else
        if exists('defaults.preventCustomBindings')
            let bindings = defaults.bindings
        else
            let bindings = g:Gitv_CustomMappings[a:mapId]
        endif
    endif
    return s:TransformBindings(bindings) + permanentBindings
endf "}}}
fu! s:GetMapCmd(mapId, mappings) "{{{
    " gets the map command from the dictionary of defaults
    " if it does not exist, returns 'nnoremap'
    let defaults = a:mappings[a:mapId]
    if !exists('defaults.mapCmd')
        return 'nnoremap'
    endif
    return defaults.mapCmd
endf "}}}
fu! s:GetMapOpts(mapId, mappings) "{{{
    " gets the map options from the dictionary of defaults
    " if it does not exist, returns '<buffer> <silent>'
    let defaults = a:mappings[a:mapId]
    if !exists('defaults.mapOpts')
        return '<buffer> <silent>'
    endif
    return defaults.mapOpts
endf "}}}
fu! s:ApplyMapping(descriptor) "{{{
    " executes a map descriptor to apply the mappings
    let prefix = a:descriptor.mapCmd . ' ' . a:descriptor.mapOpts . ' '
    let suffix = a:descriptor.cmd
    for binding in a:descriptor.bindings
        let cmd = prefix . binding.prefix . binding.keys . ' ' . suffix
        exec cmd
    endfor
endf "}}}
fu! s:GetMapDescriptor(mapId, mappings) "{{{
    " builds a complete map descriptor
    " a complete map descriptor has all possible fields
    if !exists('a:mappings[a:mapId]')
        return 0
    endif
    let descriptor={
        \'mapCmd': s:GetMapCmd(a:mapId, a:mappings),
        \'mapOpts': s:GetMapOpts(a:mapId, a:mappings),
        \'cmd': a:mappings[a:mapId].cmd,
        \'bindings': s:GetBindings(a:mapId, a:mappings)
    \}
    return descriptor
endf "}}}
fu! s:SetupMapping(mapId, mappings) "{{{
    " sets up a single mapping using defaults or custom descriptors
    let mapping = s:GetMapDescriptor(a:mapId, a:mappings)
    if type(mapping) != 4 " dictionary
        echoerr "Invalid mapping: ".a:mapId
    else
        call s:ApplyMapping(mapping)
    endif
endf "}}}
fu! s:SetupBackgroundMapping(mapId, binding) "{{{
endf "}}}
fu! s:SetupMappings() "{{{
    call s:SetDefaultMappings()
    "operations
    for mapId in keys(s:defaultMappings)
        call s:SetupMapping(mapId, s:defaultMappings)
    endfor
endf "}}} }}}
fu! s:SetupBufferCommands(fileMode) "{{{
    exec 'silent command! -buffer -nargs=* -complete=customlist,<SNR>'.s:fugitiveSid.'_GitComplete Git call <sid>MoveIntoPreviewAndExecute("unsilent Git <args>",1)| call <sid>NormalCmd("update", s:defaultMappings)'
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
" nvim sometimes opens a new window to execute commands.
" These utilities allow for temporarily exiting and re-entering the terminal.
" The terminal should ultimately be re-focused immediately after executing some command in gitv.
" This will show the output to the user.
fu! s:MoveOutOfNvimTerminal() "{{{
    let terminalIsOpen = has('nvim') && &buftype == 'terminal'
    if terminalIsOpen | tabn | endif
    return terminalIsOpen
endf "}}}
fu! s:MoveIntoNvimTerminal(terminalIsOpen) "{{{
    if a:terminalIsOpen | tabp | endif
endf "}}}
fu! s:GetParentSha(sha, parentNum) "{{{
    if a:parentNum < 1
        return
    endif
    let hashCmd = "git log -n1 --pretty=format:%p " . a:sha
    let [result,cmd] = s:RunGitCommand(hashCmd, 1)
    let parents=split(result, ' ')
    if a:parentNum > len(parents)
        return
    endif
    return parents[a:parentNum-1]
endf "}}}
fu! s:GetConfirmString(list, ...) "{{{ {{{
    "returns a string to be used with confirm out of the choices in a:list
    "any extra arguments are appended to the list of choices
    "attempts to assign unique shortcut keys to every choice
    "NOTE: choices must not be single letters and duplicates will be removed.
    let totalList = a:list + a:000
    let G = s:ConfirmStringBipartiteGraph(totalList)
    let matches = s:MaxBipartiteMatching(G)
    let choices = []
    for choice in totalList
        let shortcutChar = get(matches, choice, '')
        if shortcutChar != ''
            call add(choices, substitute(choice, '\c'.shortcutChar, '\&\0', ''))
        endif
    endfor
    return join(choices, "\n")
endfu "}}}
"Max Bipartite Matching Functions: "{{{
let s:SOURCE_NODE = '__SOURCE__'
let s:SINK_NODE = '__SINK__'
fu! s:ConfirmStringBipartiteGraph(list) "{{{
    let G = {}
    let G[s:SOURCE_NODE] = {}
    for word in a:list
        let G[word] = {}
        let G[s:SOURCE_NODE][word] = 1
        for i in range(len(word))
            let char = tolower(word[i])
            let G[word][char] = 1
            if !has_key(G, char) | let G[char] = {} | endif
            let G[char][s:SINK_NODE] = 1
        endfor
    endfor
    return G
endfu "}}}
fu! s:MaxBipartiteMatching(G) "{{{
    let f = s:InitialiseFlow(a:G)
    let path = s:GetPathInResidual(a:G, f, s:SOURCE_NODE, s:SINK_NODE)
    while path != []
        let pathCost = 100000 "max path cost should be 1 so this is effectively infinite
        for [u, v] in s:Partition(path)
            let pathCost = min([pathCost, s:GetEdge(a:G, u, v) - s:GetEdge(f, u, v)])
        endfor
        for [u, v] in s:Partition(path)
            let f[u][v] = s:GetEdge(f, u, v) + pathCost
            let f[v][u] = -s:GetEdge(f, u, v)
        endfor
        let path = s:GetPathInResidual(a:G, f, s:SOURCE_NODE, s:SINK_NODE)
    endwhile
    "f holds max flow for each edge, due to construction: include edge iff flow is 1
    let returnDict = {}
    for n1 in keys(f)
        for [n2, val] in items(f[n1])
            if val == 1
                let returnDict[n1] = n2
            endif
        endfor
    endfor
    return returnDict
endfu "}}}
fu! s:InitialiseFlow(G) "{{{
    let f = {}
    for u in keys(a:G)
        let f[u] = {}
        for v in keys(a:G[u])
            let f[u][v] = 0
            if !has_key(f, v) | let f[v] = {} | endif
            let f[v][u] = 0
        endfor
    endfor
    return f
endfu "}}}
fu! s:GetPathInResidual(G, f, s, t) "{{{
    "setup residual network
    let Gf = deepcopy(a:f, 1)
    for u in keys(a:f)
        for v in keys(a:f[u])
            let Gf[u][v] = s:GetEdge(a:G, u, v) - a:f[u][v]
        endfor
    endfor
    return s:BFS(Gf, a:s, a:t)
endfu "}}}
fu! s:Partition(path) "{{{
    "returns a list of [u,v] for the path
    if len(a:path) < 2 | return a:path | endif
    let parts = []
    for i in range(len(a:path)-1)
        let parts = add(parts, [a:path[i], a:path[i+1]])
    endfor
    return parts
endfu "}}}
fu! s:BFS(G, s, t) "{{{
    "BFS for t from s -- returns path
    return s:BFSHelp(a:G, a:s, a:t, [], [], {})
endfu "}}}
fu! s:BFSHelp(G, s, t, q, acc, visited) "{{{
    if a:s == a:t
        return a:acc + [a:t]
    endif
    let a:visited[a:s] = 1
    let children = s:GetEdges(a:G, a:s)
    call filter(children, '!get(a:visited, v:val, 0)')
    if empty(a:q) && empty(children) | return [] | endif

    let newq = empty(children) ? a:q : a:q + [[a:acc+[a:s], children]]
    let newAcc = a:acc
    if type(newq[0]) == type([])
        let newAcc = newq[0][0]
        let newq = newq[0][1] + newq[1:]
    endif
    return s:BFSHelp(a:G, newq[0], a:t, newq[1:], newAcc, a:visited)
endfu "}}}
fu! s:GetEdge(G, u, v) "{{{
    "returns 0 if edge does not exist
    return get(get(a:G, a:u, {}), a:v, 0)
endfu "}}}
fu! s:GetEdges(G, u) "{{{
    let e = []
    for k in keys(get(a:G, a:u, {}))
        let e += a:G[a:u][k] > 0 ? [k] : []
    endfor
    return e
endfu "}}} }}} }}}
fu! s:RecordBufferExecAndWipe(cmd, wipe) "{{{
    "this should be used to replace the buffer in a window
    let buf = bufnr('%')
    exec a:cmd
    if a:wipe
        "safe guard against wiping out buffer you're in
        if bufnr('%') != buf && bufexists(buf)
            " ignore errors from bdelete -- the user won't care if it's
            " already deleted
            exec 'silent! bdelete ' . buf
        endif
    endif
endfu "}}}
fu! s:SwitchBetweenWindows() "{{{
    let currentType = &filetype
    if currentType == 'gitv'
        if s:IsFileMode()
            return
        endif
        let targetType = 'git'
    else
        let targetType = 'gitv'
    endif
    let winnum = -1
    windo exec 'if &filetype == targetType | let winnum = winnr() | endif'
    if winnum != -1
        execute winnum.'wincmd w'
    endif
endfu "}}}
fu! s:MoveIntoPreviewAndExecute(cmd, tryToOpenNewWin) "{{{
    if winnr("$") == 1 "is the only window
        call s:AttemptToCreateAPreviewWindow(a:tryToOpenNewWin, a:cmd, 0)
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
        call s:AttemptToCreateAPreviewWindow(a:tryToOpenNewWin, a:cmd, 1)
        return
    endif

    silent exec a:cmd
    let terminalStatus = s:MoveOutOfNvimTerminal()

    " Move back into the branch viewer
    if horiz || filem
        wincmd k
    else
        wincmd h
    endif

    call s:MoveIntoNvimTerminal(terminalStatus)
endfu "}}}
fu! s:AttemptToCreateAPreviewWindow(shouldAttempt, cmd, shouldWarn) "{{{
    if a:shouldAttempt
        call s:CreateNewPreviewWindow()
        call s:MoveIntoPreviewAndExecute(a:cmd, 0)
    elseif a:shouldWarn
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
fu! s:GetRange() "{{{
    return exists('b:Gitv_FileModeRange') ? b:Gitv_FileModeRange : []
endfu "}}}
fu! s:SetRange(idx, value) "{{{
    "idx - {0,1}, 0 for beginning, 1 for end.
    let b:Gitv_FileModeRange[a:idx] = a:value
endfu "}}}
fu! s:FoldToRevealOnlyRange(rangeStart, rangeEnd) "{{{
    setlocal foldmethod=manual
    normal zE
    let rangeS = '/'.escape(matchstr(a:rangeStart, '/\zs.*\ze/'), '~[]/\.^$*').'/'
    let rangeE = '/'.escape(matchstr(a:rangeEnd, '/\zs.*\ze/'), '~[]/\.^$*').'/'
    exec '1,'.rangeS.'-1fold'
    exec rangeE.'+1,$fold'
endfu "}}}
fu! s:OpenRelativeFilePath(sha, geditForm) "{{{
    let relPath = s:GetRelativeFilePath()
    if relPath == ''
        return
    endif
    let cmd = a:geditForm . " " . a:sha . ":" . relPath
    let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(a:geditForm=='Gedit').')'
    call s:MoveIntoPreviewAndExecute(cmd, 1)
    let range = s:GetRange()
    if range != []
        let rangeS = escape(range[0], '"')
        let rangeE = escape(range[1], '"')
        call s:MoveIntoPreviewAndExecute('call s:FoldToRevealOnlyRange("'.rangeS.'", "'.rangeE.'")', 0)
    endif
endf "}}} }}}
"Mapped Functions:"{{{
"Operations: "{{{
fu! s:GetCommitMsg() "{{{
    return fugitive#repo().tree().'/.git/COMMIT_EDITMSG'
endf "}}}
fu! s:OpenGitvCommit(geditForm, forceOpenFugitive) "{{{
    let bindingsCmd = 'call s:MoveIntoPreviewAndExecute("call s:SetupMapping('."'".'toggleWindow'."'".', s:defaultMappings)", 0)'
    let line = getline('.')
    if line == "-- Load More --"
        call s:LoadGitv('', 1, b:Gitv_CommitCount+g:Gitv_CommitStep, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
        return
    endif
    if s:IsFileMode() && line =~ "^-- \\[.*\\] --$"
        call s:OpenWorkingCopy(a:geditForm)
        return
    endif
    if line =~ s:pendingRebaseMsg.'$' || line =~ s:rebaseMsg.'$'
        call s:RebaseEdit()
        return
    endif
    if line =~ s:localUncommitedMsg.'$'
        call s:OpenWorkingDiff(a:geditForm, 0)
        exec bindingsCmd
        return
    endif
    if line =~ s:localCommitedMsg.'$'
        call s:OpenWorkingDiff(a:geditForm, 1)
        exec bindingsCmd
        return
    endif
    if s:IsFileMode() && line =~ '^-- /.*/$'
        if s:EditRange(matchstr(line, '^-- /\zs.*\ze/$'))
            call s:NormalCmd('update', s:defaultMappings)
        endif
        return
    endif
    let sha = gitv#util#line#sha(line('.'))
    if sha == ""
        return
    endif
    if s:IsFileMode() && !a:forceOpenFugitive
        call s:OpenRelativeFilePath(sha, a:geditForm)
    else
        let opts = g:Gitv_PreviewOptions
        if opts == ''
            let cmd = a:geditForm . " " . sha
            let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(a:geditForm=='Gedit').')'
        else
            let winCmd = a:geditForm[1:] == 'edit' ? '' : a:geditForm[1:]
            let cmd = 'call Gitv_OpenGitCommand(\"show '.opts.' --no-color '.sha.'\", \"'.winCmd.'\")'
            let cmd = 'call s:RecordBufferExecAndWipe("'.cmd.'", '.(winCmd=='').')'
        endif
        call s:MoveIntoPreviewAndExecute(cmd, 1)
        call s:MoveIntoPreviewAndExecute('setlocal fdm=syntax', 0)
        exec bindingsCmd
    endif
endf
fu! s:OpenWorkingCopy(geditForm)
    let fp = s:GetRelativeFilePath()
    let form = a:geditForm[1:] "strip off the leading 'G'
    let cmd = form . " " . fugitive#repo().tree() . "/" . fp
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
endfu
fu! s:EditRange(rangeDelimiter)
    let range = s:GetRange()
    let rangeDelimWithSlashes = '/'.a:rangeDelimiter.'/'
    let idx = rangeDelimWithSlashes == range[0] ? 0 : rangeDelimWithSlashes == range[1] ? 1 : -1
    if idx == -1
        return 0
    endif
    let value = input("Enter new range regex: ", a:rangeDelimiter)
    let value = '/'.value.'/'
    if value == range[idx]
        return 0 "no need to update
    endif
    call s:SetRange(idx, value)
    return 1
endfu "}}}
" Rebase: "{{{
fu! s:RebaseHasInstructions() "{{{
    return exists('b:Gitv_RebaseInstructions') && len(keys(b:Gitv_RebaseInstructions)) > 0
endf "}}}
fu! s:RebaseClearInstructions() "{{{
    let b:Gitv_RebaseInstructions = {}
endf "}}}
fu! s:RebaseSetInstruction(instruction) range "{{{
    if s:IsFileMode()
        return
    endif
    if s:BisectHasStarted()
        echo "Cannot set rebase instructions in bisect mode."
        return
    endif
    if s:RebaseIsEnabled()
        echo "Rebase already in progress."
        return
    endif
    if a:instruction == 'x'
        let cmd = input('Please enter a command to execute for each commit: ')
        if cmd == ''
            echo 'Not marking any commits for exec.'
            return
        endif
    endif
    let ncommits = 0
    for line in range(a:firstline, a:lastline)
        let sha = gitv#util#line#sha(line)
        if sha == ''
            continue
        endif
        let ncommits += 1
        if a:instruction == 'p' || a:instruction == 'pick' || a:instruction == ''
            if !exists('b:Gitv_RebaseInstructions[sha]')
                continue
            endif
            call remove(b:Gitv_RebaseInstructions, sha)
        else
            if exists('cmd')
                if !exists('b:Gitv_RebaseInstructions[sha]')
                    let b:Gitv_RebaseInstructions[sha] = { 'instruction': 'p' }
                endif
                let b:Gitv_RebaseInstructions[sha].cmd = cmd
            else
                let b:Gitv_RebaseInstructions[sha] = { 'instruction': a:instruction }
            endif
        endif
    endfor
    if ncommits < 1
        echo "No commits marked."
        return
    elseif ncommits > 1
        let prettyCommit = ncommits .' commits'
    else
        let prettyCommit = gitv#util#line#sha('.')
    endif
    call s:RebaseUpdateView()
    if exists('cmd')
        redraw
        echo cmd 'will be executed after' prettyCommit.'.'
    else
        echo prettyCommit.' marked with "'.a:instruction.'".'
    endif
endf "}}}
fu! s:RebaseHasStarted() "{{{
    return !empty(glob(fugitive#repo().tree().'/.git/rebase-merge'))
endf "}}}
fu! s:RebaseGetRefs(line) "{{{
    let sha = gitv#util#line#sha(a:line)
    if sha == ""
        return []
    endif
    return gitv#util#line#refs(a:line) + [sha]
endf "}}}
fu! s:RebaseGetChoice(refs, purpose) "{{{
    let msg = "Choose destination to rebase ".a:purpose.":"
    let choice = confirm(msg, s:GetConfirmString(a:refs, "Cancel"))
    if choice == 0 || choice > len(a:refs)
        return ''
    endif
    let choice = a:refs[choice - 1]
    let choice = substitute(choice, "^t:", "", "")
    let choice = substitute(choice, "^r:", "", "")
    return choice
endf "}}}
fu! s:RebaseGetRange(first, last, fromPlaceholder, ontoPlaceholder) "{{{
    " will attempt to grab a reference from a range of lines
    " if the range is 0, will only grab one reference and use a placeholder for the other
    " at least one placeholder must be given
    " the placeholder can be an empty string
    " for no placeholder, use a number
    if a:first != a:last
        let msg = 'Rebase from top or bottom?'
        let choice = confirm(msg, "&top\n&bottom\n&cancel")
        if choice == 0 || choice == 3
            return []
        endif
    else
        let choice = 1
    endif
    if choice == 1
        let from = a:first
        let onto = a:last
    else
        let from = a:last
        let onto = a:first
    endif

    " get refs
    if a:first != a:last || type(a:fromPlaceholder) != 1 " string
        let fromRefs = s:RebaseGetRefs(from)
        if !len(fromRefs)
            return []
        endif
    else
        let fromRefs = from
    endif
    if a:first != a:last || type(a:ontoPlaceholder) != 1
        let ontoRefs = s:RebaseGetRefs(onto)
        if !len(ontoRefs)
            return []
        endif
    else
        let ontoRefs = onto
    endif

    " set placeholder
    if a:first == a:last
        if type(a:fromPlaceholder) == 1
            unlet fromRefs
            let fromRefs = a:fromPlaceholder
        elseif type(a:ontoPlaceholder) == 1
            unlet ontoRefs
            let ontoRefs = a:ontoPlaceholder
        else
            echoerr 'A default must be given.'
            return []
        endif
    endif

    " get choices
    if a:first != a:last || type(a:fromPlaceholder) != 1
        let fromChoice = s:RebaseGetChoice(fromRefs, 'from')
        if fromChoice == ''
            return []
        endif
    else
        let fromChoice = fromRefs
    endif
    if a:first != a:last || type(a:ontoPlaceholder) != 1
        let ontoChoice = s:RebaseGetChoice(ontoRefs, 'onto')
        if ontoChoice == ''
            return []
        endif
    else
        let ontoChoice = ontoRefs
    endif

    return [fromChoice, ontoChoice]
endf "}}}
fu! s:Rebase() range "{{{
    if s:IsFileMode()
        return
    endif
    if s:BisectIsEnabled() || s:BisectHasStarted()
        echo "Cannot rebase in bisect mode."
        return
    endif
    if s:RebaseHasStarted()
        echoerr "Rebase already in progress."
        return
    endif
    let choice = s:RebaseGetRange(a:firstline, a:lastline, 'HEAD', 0)
    if !len(choice)
        redraw
        echo "Not rebasing."
        return
    endif
    let result = s:RunGitCommand('rebase '.choice[0].' '.choice[1], 0)[0]
    let hasError = v:shell_error
    call s:RebaseUpdateView()
    if hasError
        redraw
        echoerr split(result, '\n')[0]
    endif
endf "}}}
fu! s:SetRebaseEditor() "{{{
    " override the default editor used for interactive rebasing
    if  s:RebaseHasInstructions()
        " replace default instructions with stored instructions
        let $GIT_SEQUENCE_EDITOR='function gitv_edit() {'
        for sha in keys(b:Gitv_RebaseInstructions)
            let short = sha[0:6]
            let instruction = b:Gitv_RebaseInstructions[sha].instruction
            let $GIT_SEQUENCE_EDITOR .= ' SHA_'.short.'='.instruction.';'
            if exists('b:Gitv_RebaseInstructions[sha].cmd')
                let cmd = b:Gitv_RebaseInstructions[sha].cmd
                let $GIT_SEQUENCE_EDITOR .= ' CMD_'.short.'='.shellescape(cmd).';'
            endif
        endfor
        let $GIT_SEQUENCE_EDITOR .= 'while read line; do
                    \ if [[ $line == "" ]]; then break; fi;
                    \ sha=${line:5:7};
                    \ key=SHA_$sha;
                    \ if [[ ${!key} != "" ]]; then
                    \ cmd=CMD_$sha;
                    \ echo ${!key} ${line:5};
                    \ if [[ ${!cmd} != "" ]]; then
                    \ echo x ${!cmd};
                    \ fi;
                    \ else
                    \ echo $line;
                    \ fi;
                    \ done < $1 > '.s:workingFile.';
                    \ mv '.s:workingFile.' $1;
                    \ }; gitv_edit'
    else
        " change pick to edit
        let $GIT_SEQUENCE_EDITOR='function gitv_edit() {
                    \ echo "" > '.s:workingFile.';
                    \ while read line; do
                    \ if [[ "${line:0:4}" == "pick" ]]; then
                    \ echo "edit ${line:5}";
                    \ else
                    \ echo $line;
                    \ fi;
                    \ done < $1 > '.s:workingFile.';
                    \ mv '.s:workingFile.' $1;
                    \ }; gitv_edit'
    endif
endf "}}}
fu! s:RebaseUpdateView() "{{{
    " attempt to move out of the rebase/commit/preview window and update
    wincmd j
    wincmd h
    wincmd j
    if &ft == 'gitv'
        call s:NormalCmd('update', s:defaultMappings)
    endif
endf "}}}
fu! s:RebaseAbort() "{{{
    if s:RebaseHasStarted()
        echo 'Abort current rebase? (y/n) '
        if nr2char(getchar()) == 'y'
            call s:RunGitCommand('rebase --abort', 0)
            call s:RebaseUpdateView()
        endif
        return
    else
        echo 'Rebase not in progress.'
    endif
endf "}}}
fu! s:RebaseUpdate() "{{{
    if s:RebaseHasInstructions() && (s:BisectIsEnabled() || s:RebaseHasStarted() || s:BisectHasStarted())
        echoerr "Mode changed elsewhere, dropping rebase instructions."
        let b:Gitv_RebaseInstructions = {}
    endif
    if !s:RebaseHasStarted() && s:RebaseIsEnabled()
        let b:Gitv_Rebasing = 0
    endif
endf "}}}
fu! s:RebaseIsEnabled() "{{{
    return exists('b:Gitv_Rebasing') && b:Gitv_Rebasing == 1
endf "}}}
fu! s:RebaseToggle() range "{{{
    if s:IsFileMode()
        return
    endif
    if s:RebaseIsEnabled()
        let b:Gitv_Rebasing = 0
        call s:RebaseUpdateView()
        return
    elseif s:RebaseHasStarted()
        let b:Gitv_Rebasing = 1
        call s:RebaseUpdateView()
        return
    elseif s:BisectIsEnabled() || s:BisectHasStarted()
        echoerr "Cannot rebase in bisect mode."
        return
    endif
    let choice = s:RebaseGetRange(a:firstline, a:lastline, 0, '')
    if !len(choice)
        redraw
        echo "Not rebasing."
        return
    endif
    let b:Gitv_Rebasing = 1
    call s:SetRebaseEditor()
    let cmd = 'rebase --preserve-merges --interactive '.choice[0]
    if s:RebaseHasInstructions()
        " we don't know what the instructions are, treat it like a continue
        call s:RebaseContinueSetup()
        " only jump to the commit before this
        let cmd .= '^'
    else
        " jump to two commits before so we can stop and edit
        let cmd .= '~2'
    endif
    let cmd .= ' '.choice[1]
    let result=s:RunGitCommand(cmd, 0)[0]
    let result = split(result, '\n')[0]
    let hasError = v:shell_error
    let hasInstructions = s:RebaseHasInstructions()
    call s:RebaseClearInstructions()
    call s:RebaseUpdateView()
    let $GIT_SEQUENCE_EDITOR=""
    if hasError && !hasInstructions
        echoerr result
        return
    elseif !hasError && hasInstructions
        echo result
    endif
    if hasInstructions
        call s:RebaseContinueCleanup()
    else
        call s:RebaseEdit()
    endif
endf "}}}
fu! s:RebaseSkip() "{{{
    if !s:RebaseIsEnabled()
        return
    endif
    for i in range(0, v:count)
        let result = split(s:RunGitCommand('rebase --skip', 0)[0], '\n')[0]
        let hasError = v:shell_error
        if i == v:count || hasError
            call s:RebaseUpdateView()
        endif
        if hasError
            echoerr result
            return
        else
            echo result
        endif
    endfor
endf "}}}
fu! s:GetRebaseMode() "{{{
    let output = readfile(s:GetRebaseDone())
    let length = len(output)
    if length < 1
        return ''
    endif
    return output[length - 1][0]
endf "}}}
fu! s:RebaseContinueSetup() "{{{
    " override the commit editor in a way that lets us take over rebase
    let $GIT_EDITOR='exit 1'
endf "}}}
fu! s:RebaseContinue() "{{{
    if !s:RebaseIsEnabled()
        return
    endif
    call s:RebaseContinueSetup()
    let result = s:RunGitCommand('rebase --continue', 0)[0]
    " we expect an error because of what we did with exit
    if !v:shell_error
        echo split(result, '\n')[0]
    endif
    call s:RebaseUpdateView()
    call s:RebaseContinueCleanup()
endf "}}}
fu! s:RebaseContinueCleanup() "{{{
    let $GIT_EDITOR=""
    if !s:RebaseIsEnabled()
        return
    endif
    let mode = s:GetRebaseMode()
    if mode == 's'
        " errors with squash cause us to fall through to the next commit
        " the desired commit message is still in place when we fall through
        call writefile([], s:workingFile)
        call writefile(readfile(s:GetCommitMsg()), s:workingFile)
        let result = s:RunGitCommand('reset --soft HEAD~1', 0)[0]
        if v:shell_error
            echoerr split(result, '\n')[0]
            return
        endif
    endif
    if mode == 'r' || mode == 's'
        if mode == 'r'
            Gcommit --amend
        else
            Gcommit
        endif
        set modifiable
        if &ft == 'gitcommit'
            if mode == 's'
                call writefile(readfile(s:workingFile), s:GetCommitMsg())
            endif
        endif
    endif
endf "}}}
fu! s:GetRebaseHeadname() "{{{
    return fugitive#repo().tree().'/.git/rebase-merge/head-name'
endf "}}}
fu! s:GetRebaseDone() "{{{
    return fugitive#repo().tree().'/.git/rebase-merge/done'
endf "}}}
fu! s:GetRebaseTodo() "{{{
    return fugitive#repo().tree().'/.git/rebase-merge/git-rebase-todo'
endf "}}}
fu! s:RebaseViewInstructions() "{{{
    exec 'edit' s:workingFile
    if expand('%') == s:workingFile
        silent setlocal syntax=gitrebase
        silent setlocal nomodifiable
    endif
endf "}}}
fu! s:RebaseEditTodo() "{{{
    exec 'edit' s:GetRebaseTodo()
    if &ft == 'gitrebase'
        silent setlocal modifiable
        silent setlocal noreadonly
        silent setlocal buftype
        silent setlocal nobuflisted
        silent setlocal noswapfile
        silent setlocal bufhidden=wipe
    endif
endf "}}
fu! s:RebaseEdit() "{{{
    if s:RebaseHasInstructions()
        " rebase should not be started, but we have set instructions to view
        let output = []
        for key in keys(b:Gitv_RebaseInstructions)
            let line = b:Gitv_RebaseInstructions[key].instruction.' '.key
            if exists('b:Gitv_RebaseInstructions[key].cmd')
                let line .= ' '.b:Gitv_RebaseInstructions[key].cmd
            endif
            call add(output, line)
        endfor
        call writefile(output, s:workingFile)
        call s:MoveIntoPreviewAndExecute('call s:RebaseViewInstructions()', 1)
    endif
    if !s:RebaseHasStarted()
        return
    endif
    let todo = s:GetRebaseTodo()
    if empty(glob(todo))
        echoerr 'No interactive rebase in progress.'
        return
    endif
    call s:MoveIntoPreviewAndExecute('call s:RebaseEditTodo()', 1)
    wincmd l
endf "}}} }}}
"Bisect: "{{{
fu! s:IsBisectingFiles(filePaths) "{{{
    let path = fugitive#repo().tree().'/.git/BISECT_NAMES'
    if empty(glob(path))
        return 0
    endif
    let paths = ''
    for filePath in a:filePaths
        let paths .= " '".filePath."'"
    endfor
    return join(readfile(path), ' ') == paths
endf "}}}
fu! s:IsBisectingCurrentFiles() "{{{
    if s:IsFileMode() && !s:IsBisectingFiles([b:Gitv_FileModeRelPath])
        return 0
    endif
    if b:Gitv_ExtraArgs[1] != '' && !s:IsBisectingFiles(split(b:Gitv_ExtraArgs[1], ' '))
        return 0
    endif
    return 1
endf "}}}
fu! s:BisectUpdate() "{{{
    if s:BisectIsEnabled() && !s:BisectHasStarted()
        echoerr "Mode changed elsewhere, dropping bisect."
        let b:Gitv_Bisecting = 0
    endif
endf "}}}
fu! s:BisectIsEnabled() "{{{
    return exists('b:Gitv_Bisecting') && b:Gitv_Bisecting == 1
endf "}}}
fu! s:BisectHasStarted() "{{{
    call s:RunGitCommand('bisect log', 0)
    return !v:shell_error
endf "}}}
fu! s:BisectStart(mode) range "{{{
    if s:RebaseHasInstructions() || s:RebaseHasStarted()
        echo "Cannot bisect in rebase mode."
        return
    endif
    if s:BisectIsEnabled()
        if g:Gitv_QuietBisect == 0
            echom 'Bisect disabled'
        endif
        let b:Gitv_Bisecting = 0
        return
    elseif !s:BisectHasStarted()
        let cmd = 'bisect start'
        if b:Gitv_ExtraArgs[1] != ''
            let cmd .= join(b:Gitv_ExtraArgs, ' ')
        elseif s:IsFileMode()
            let cmd .= ' '.b:Gitv_FileModeRelPath
        endif
        let result = s:RunGitCommand(cmd, 0)[0]
        if v:shell_error
            echoerr split(result, '\n')[0]
            return
        endif
        if a:mode == 'v'
            call s:RunGitCommand('bisect bad ' . gitv#util#line#sha(a:firstline), 0)[0]
            if a:firstline != a:lastline
                call s:RunGitCommand('bisect good ' . gitv#util#line#sha(a:lastline), 0)[0]
            endif
        endif
        let b:Gitv_Bisecting = 1
        if g:Gitv_QuietBisect == 0
            echom 'Bisect started'
        endif
    else
        if !s:IsBisectingCurrentFiles()
            echoerr "Not bisecting the current files, cannot enable."
            return
        endif
        let b:Gitv_Bisecting = 1
        if g:Gitv_QuietBisect == 0
            echom 'Bisect enabled'
        endif
    endif
    call s:LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
endf "}}}
fu! s:BisectReset() "{{{
    if s:BisectIsEnabled()
        let b:Gitv_Bisecting = 0
    endif
    if s:BisectHasStarted()
        call s:RunGitCommand('bisect reset', 0)
        if g:Gitv_QuietBisect == 0
            echom 'Bisect stopped'
        endif
    else
        if g:Gitv_QuietBisect == 0
            echom 'Bisect disabled'
        endif
    endif
    call s:LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
endf "}}}
fu! s:BisectGoodBad(goodbad) range "{{{
    let goodbad = a:goodbad . ' '
    if s:BisectIsEnabled() && s:BisectHasStarted()
        let result = ''
        if a:firstline == a:lastline
            let ref = gitv#util#line#sha('.')
            let result = s:RunGitCommand('bisect ' . goodbad . ref, 0)[0]
            if v:shell_error
                echoerr split(result, '\n')[0]
                return
            endif
            if g:Gitv_QuietBisect == 0
                echom ref . ' marked as ' . a:goodbad
            endif
        else
            let refs2 = gitv#util#line#sha(a:firstline)
            let refs1 = gitv#util#line#sha(a:lastline)
            let refs = refs1 . "^.." . refs2
            let cmd = 'log --pretty=format:%h '
            let reflist = split(s:RunGitCommand(cmd . refs, 0)[0], '\n')
            if v:shell_error
                echoerr reflist[0]
                return
            endif
            let errors = 0
            for ref in reflist
                let result = s:RunGitCommand('bisect ' . goodbad . ref, 0)[0]
                if v:shell_error
                    echoerr split(result, '\n')[0]
                    errors += 1
                endif
            endfor
            if g:Gitv_QuietBisect == 0
                echom refs . ' commits marked as ' . a:goodbad
            endif
            if errors == len(reflist)
                return
            endif
        endif
        call s:LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
    endif
endf "}}}
fu! s:BisectSkip(mode) range "{{{
    if s:BisectIsEnabled() && s:BisectHasStarted()
        if a:mode == 'n'
            let loops = abs(v:count || 1)
            let loop = 0
            let errors = 0
            while loop < loops
                let result = s:RunGitCommand('bisect skip', 0)[0]
                if v:shell_error
                    echoerr split(result, '\n')[0]
                    let errors += 1
                endif
                let loop += 1
            endwhile
            if g:Gitv_QuietBisect == 0
                echom loop - errors . ' commits skipped'
            endif
            if errors == loops
                return
            endif
        else "visual mode or no range
            let cmd = 'bisect skip '
            let refs = gitv#util#line#sha(a:lastline)
            if a:firstline != a:lastline
                let refs2 = gitv#util#line#sha(a:firstline)
                let refs .= "^.." . refs2
            endif
            let result = s:RunGitCommand('bisect skip ' . refs, 0)[0]
            if v:shell_error
                echoerr split(result, '\n')[0]
                return
            else
                if g:Gitv_QuietBisect == 0
                    echom refs . 'skipped'
                endif
            endif
        endif
        call s:LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
    endif
endf "}}}
fu! s:BisectLog() "{{{
    if !s:BisectHasStarted()
        return
    endif
    let fname = input('Enter a filename to save the log to: ', '', 'file')
    let result = split(s:RunGitCommand('bisect log', 0)[0], '\n')
    if v:shell_error
        echoerr result[0]
        return
    endif
    call writefile(result, fname)
endf "}}}
fu! s:BisectReplay() "{{{
    let fname = input('Enter a filename to replay: ', '', 'file')
    let result = s:RunGitCommand('bisect replay ' . fname, 0)[0]
    if v:shell_error
        echoerr split(result, '\n')[0]
        return
    endif
    let b:Gitv_Bisecting = 1
    call s:LoadGitv('', 1, b:Gitv_CommitCount, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
endf "}}} }}}
fu! s:CheckOutGitvCommit() "{{{
    let allrefs = gitv#util#line#refs('.')
    let sha = gitv#util#line#sha(line('.'))
    if sha == ""
        return
    endif
    let refs   = allrefs + [sha]
    let refstr = s:GetConfirmString(refs, 'Cancel')
    let choice = confirm("Checkout commit:", refstr)
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
        "only tab: quit vim
        if tabpagenr() == tabpagenr('$') && tabpagenr() == 1
            qa
        endif

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
    let shafirst = gitv#util#line#sha(a:firstline)
    let shalast  = gitv#util#line#sha(a:lastline)
    if shafirst == "" || shalast == ""
        return
    endif
    if a:firstline != a:lastline
        call s:OpenRelativeFilePath(shafirst, "Gedit")
    endif
    call s:MoveIntoPreviewAndExecute("Gdiff " . shalast, a:firstline != a:lastline)
endf "}}}
fu! s:GetMergeArguments(from, to, verbose) "{{{
    if exists('g:Gitv_MergeArgs') && type(g:Gitv_MergeArgs) == 1
        if a:verbose
            echom "Merging '" . a:from . "' in to '" . a:to . "' with arguments '" . g:Gitv_MergeArgs . "'."
        endif
        " safely pad with spaces to avoid returning base value, put space before merge ref
        return g:Gitv_MergeArgs . ' '
    endif

    let choices = "&Yes\n&No\n&Cancel"
    let ff = confirm("Use fast-forward, if possible, to merge '". a:from . "' in to '" . a:to ."'?", choices)
    if ff == 0 || ff == 3 | return "" | endif
    let ff = ff == 1 ? ff : 0

    if a:verbose
        if ff
            echom "Merging '" . a:from . "' in to '" . a:to . "' with fast-forward."
        else
            echom "Merging '" . a:from . "' in to '" . a:to . "' without fast-forward."
        endif
    endif

    if ff
        return '--ff '
    else
        return '--no-ff '
    endif
endfu
fu! s:MergeBranches() range
    if a:firstline == a:lastline
        echom 'Already up to date.'
        return
    endif
    let refs = gitv#util#line#refs(a:firstline)
    let refs += gitv#util#line#refs(a:lastline)
    call filter(refs, 'v:val !=? "HEAD"')
    if len(refs) < 2
        echom 'Not enough refs found to perform a merge.'
        return
    endif
    let target = confirm("Choose target branch to merge into:", s:GetConfirmString(refs, "Cancel"))
    if target == 0 || get(refs, target-1, '')=='' | return | endif
    let target = remove(refs, target-1)
    let target = substitute(target, "^[tr]:", "", "")

    let merge = confirm("Choose branch to merge in to '".target."':", s:GetConfirmString(refs, "Cancel"))
    if merge == 0 || get(refs, merge-1, '')==''| return | endif
    let merge = refs[merge-1]
    let merge = substitute(merge, "^[tr]:", "", "")

    let mergeArgs = s:GetMergeArguments(merge, target, 1)
    if mergeArgs == "" | return | endif

    call s:PerformMerge(target, merge, args)
endfu
fu! s:PerformMerge(target, mergeBranch, mergeArgs) abort
    exec 'Git checkout ' . a:target
    exec 'Git merge ' . a:mergeArgs . a:mergeBranch

    if g:Gitv_PromptToDeleteMergeBranch
        let choices = "&Yes\n&No\n&Cancel"
        let delBranch = confirm("Delete merge branch: '" . a:mergeBranch . "'?", choices)
        if delBranch == 0 || delBranch == 3 | return | endif
        let delBranch = delBranch == 1 ? delBranch : 0
        if delBranch
            exec 'Git branch -d ' . a:mergeBranch
        endif
    endif
endfu
fu! s:MergeToCurrent()
    let refs = gitv#util#line#refs(".")
    call filter(refs, 'v:val !=? "HEAD"')
    if len(refs) < 1
        echoerr 'No ref found to perform a merge.'
        return
    endif
    let target = refs[0]
    let target = substitute(target, "^[tr]:", "", "")

    let mergeArgs = s:GetMergeArguments(target, 'HEAD', 0)
    if mergeArgs == "" | return | endif

    call s:PerformMerge("HEAD", target, mergeArgs)
endfu "}}}
fu! s:CherryPick() range "{{{
    let refs2 = gitv#util#line#sha(a:firstline)
    let refs1 = gitv#util#line#sha(a:lastline)
    if refs1 == refs2
        let refs = refs1
    else
        let refs = refs1 . "^.." . refs2
    endif

    echom "Cherry-Pick " . refs
    exec 'Git cherry-pick ' . refs
endfu "}}}
fu! s:ResetBranch(mode) range "{{{
    let ref = gitv#util#line#sha(a:firstline)

    echom "Reset " . a:mode . " to " . ref
    exec 'Git reset ' . a:mode . " " . ref
endfu "}}}
fu! s:Revert() range "{{{
    let refs2 = gitv#util#line#sha(a:firstline)
    let refs1 = gitv#util#line#sha(a:lastline)
    let refs = refs1
    if refs1 != refs2
        let refs = refs1 . "^.." . refs2
    endif

    let mergearg = ''
    let mergerefs = split(s:RunGitCommand('show ' . refs, 0)[0], '\n')
    let mergerefs = split(matchstr(mergerefs, '^Merge:'))[1:]
    if len(mergerefs) > 0
        if refs1 != refs2
            throw 'Cannot revert a range with a merge commit.'
            return
        endif
        let mergearg = '-m 1'
    endif
    let cmd = 'revert --no-commit ' . mergearg . ' ' . refs
    let result = s:RunGitCommand(cmd, 0)[0]
    if result != ''
        throw split(result, '\n')[0]
        return
    endif
    exec 'Gcommit'
endfu "}}}
fu! s:DeleteRef() range "{{{
    let refs = gitv#util#line#refs(a:firstline)
    call filter(refs, 'v:val !=? "HEAD"')
    let choice = confirm("Choose branch to delete:", s:GetConfirmString(refs, "Cancel"))
    if choice == 0
        return
    endif
    let choice = get(refs, choice-1, "")
    if choice == ""
        return
    endif
    if match(choice, 'tag: .*') < 0
        let command = "branch"
    else
        let command = "tag"
    endif
    let choice = substitute(choice, "^t:", "", "")
    let choice = substitute(choice, "^r:", "", "")
    let choice = substitute(choice, "^tag: t:", "", "")
    if s:IsFileMode()
        let relPath = s:GetRelativeFilePath()
        let choice .= " -- " . relPath
    endif
    echom "Delete " . command . " " . choice
    exec 'Git ' . command . " -d " . choice
endfu "}}}
fu! s:StatGitvCommit() range "{{{
    let shafirst = gitv#util#line#sha(a:firstline)
    let shalast  = gitv#util#line#sha(a:lastline)
    if shafirst == "" || shalast == ""
        return
    endif
    let cmd  = 'diff --no-color '.shafirst
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
fu! s:JumpToCommit(backwards) "{{{
    let flags = 'W'
    if a:backwards
        let flags .= 'b'
    endif

    let c = v:count1
    while c > 0
        let c-=1
        call search( '^[|\/\\ ]*\zs\*', flags )
    endwhile

    redraw
    call s:OpenGitvCommit("Gedit", 0)
endf "}}}
fu! s:JumpToParent() "{{{
    let sha = gitv#util#line#sha(line('.'))
    if sha == ""
        return
    endif
    let parent = s:GetParentSha(sha, v:count1 )
    if parent == ""
        echom 'Parent '.v:count1.' is out of range'
        return
    endif
    while !search( '^\ze.*\['.parent.'\]$', 'Ws' )
        call s:LoadGitv('', 1, b:Gitv_CommitCount+g:Gitv_CommitStep, b:Gitv_ExtraArgs, s:GetRelativeFilePath(), s:GetRange())
    endwhile
    redraw
endf "}}}
"}}} }}}
"Align And Truncate Functions: "{{{
if exists("*strwidth") "{{{
  "introduced in Vim 7.3
  fu! s:StringWidth(string)
    return strwidth(a:string)
  endfu
else
  fu! s:StringWidth(string)
    return len(split(a:string,'\zs'))
  endfu
end "}}}
if exists("*strdisplaywidth") "{{{
  fu! s:StringDisplayWidth(string)
    return strdisplaywidth(a:string)
  endfu
else
  fu! s:StringDisplayWidth(string)
    return s:StrWidth(a:string,'\zs')
  endfu
end "}}}
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
                call add(newline, token . repeat(' ', maxLens[i]-s:StringWidth(token)+1))
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
fu! s:TruncateWideString(string, target) "{{{
    if !exists('*strdisplaywidth')
        return a:string
    endif
    let newString = a:string
    while strdisplaywidth(newString) > a:target
        let newString = newString[0:-2]
    endwhile
    while strdisplaywidth(newString) < a:target
        let newString .= ' '
    endwhile
    return newString
endfu "}}}
fu! s:TruncateHelp(line, filePath) "{{{
    let length = s:StringWidth(join(a:line))
    let displayLength = s:StringDisplayWidth(join(a:line))
    let maxWidth = s:IsHorizontal() ? &columns : &columns/2
    let maxWidth = a:filePath != '' ? winwidth(0) : maxWidth
    if displayLength > maxWidth
        let delta = displayLength - maxWidth
        "offset = 3 for the elipsis and 1 for truncation
        let offset = 3 + 1
        if a:line[0][-(delta + offset + 1):] =~ "^\\s\\+$"
            let extension = "   "
        else
            let extension = "..."
        endif
        if length > maxWidth
            let a:line[0] = a:line[0][:-(delta + offset)]
        endif
        let target = maxWidth - offset - s:StringWidth(join(a:line[1:-1]))
        let a:line[0] = s:TruncateWideString(a:line[0], target)
        let a:line[0] =  a:line[0] . extension
    endif
    return a:line
endfu "}}}
fu! s:MaxLengths(colls) "{{{
    "precondition: coll is a list of lists of strings -- should be rectangular
    "returns a list of maximum string lengths
    let lengths = []
    for x in a:colls
        for y in range(len(x))
            let length = s:StringWidth(x[y])
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
" Returns an array with script number and path
fu! s:GetFugitiveInfo() "{{{
    redir => scriptnames
    silent! scriptnames
    redir END
    for script in split(l:scriptnames, "\n")
        if l:script =~ 'fugitive'
            let info = split(l:script, ":")
            " Parse the script number
            let info[0] = str2nr(info[0])
            " Parse the script path
            let info[1] = expand(info[1][1:])
            return info
        endif
    endfor
    throw 'Unable to find fugitive'
endfu "}}}
fu! s:GetFugitiveSid() "{{{
    return s:GetFugitiveInfo()[0]
endfu "}}} }}}

let &cpo = s:savecpo
unlet s:savecpo

 " vim:set et sw=4 ts=4 fdm=marker:
