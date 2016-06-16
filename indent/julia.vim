" Vim indent file
" Language:	Julia
" Maintainer:	Carlo Baldassi <carlobaldassi@gmail.com>
" Last Change:	2014 may 29
" Notes:        based on Bram Molenaar's indent file for vim

setlocal autoindent

setlocal indentexpr=GetJuliaIndent()
setlocal indentkeys+==end,=else,=catch,=finally,),],}
setlocal indentkeys-=0#
setlocal indentkeys-=:
setlocal indentkeys-=0{
setlocal indentkeys-=0}
setlocal nosmartindent

" Only define the function once.
if exists("*GetJuliaIndent")
  finish
endif

let s:skipPatterns = '\<julia\%(ComprehensionFor\|RangeEnd\|CommentL\|\%([bv]\|ip\|big\|MIME\|Shell\|Tri\|Printf\)\=String\|RegEx\|InQuote\)\>'

function JuliaMatch(lnum, str, regex, st)
  let s = a:st
  while 1
    let f = match(a:str, a:regex, s)
    if f >= 0
      let attr = synIDattr(synID(a:lnum,f+1,1),"name")
      if attr =~ s:skipPatterns
        let s = f+1
        continue
      endif
    endif
    break
  endwhile
  return f
endfunction

function GetJuliaNestingStruct(lnum)
  " Auxiliary function to inspect the block structure of a line
  let line = getline(a:lnum)
  let s = 0
  let blocks_stack = []
  let num_closed_blocks = 0
  while 1
    let fb = JuliaMatch(a:lnum, line, '@\@<!\<\%(if\|else\%(if\)\=\|while\|for\|try\|catch\|finally\|\%(staged\)\?function\|macro\|begin\|type\|immutable\|let\|\%(bare\)\?module\|quote\|do\)\>', s)
    let fe = JuliaMatch(a:lnum, line, '@\@<!\<end\>', s)

    if fb < 0 && fe < 0
      " No blocks found
      break
    end

    if fb >= 0 && (fb < fe || fe < 0)
      " The first occurrence is an opening block keyword
      " Note: some keywords (elseif,else,catch,finally) are both
      "       closing blocks and opening new ones

      let i = JuliaMatch(a:lnum, line, '@\@<!\<if\>', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(blocks_stack, 'if')
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '@\@<!\<elseif\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && blocks_stack[-1] == 'if'
          let blocks_stack[-1] = 'elseif'
        elseif (len(blocks_stack) > 0 && blocks_stack[-1] != 'elseif') || len(blocks_stack) == 0
          call add(blocks_stack, 'elseif')
          let num_closed_blocks += 1
        endif
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '@\@<!\<else\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && blocks_stack[-1] =~ '\<\%(else\)\=if\>'
          let blocks_stack[-1] = 'else'
        else
          call add(blocks_stack, 'else')
          let num_closed_blocks += 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '@\@<!\<try\>', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(blocks_stack, 'try')
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '@\@<!\<catch\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && blocks_stack[-1] == 'try'
          let blocks_stack[-1] = 'catch'
        else
          call add(blocks_stack, 'catch')
          let num_closed_blocks += 1
        endif
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '@\@<!\<finally\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && (blocks_stack[-1] == 'try' || blocks_stack[-1] == 'catch')
          let blocks_stack[-1] = 'finally'
        else
          call add(blocks_stack, 'finally')
          let num_closed_blocks += 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '@\@<!\<\%(bare\)\?module\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if i == 0
          call add(blocks_stack, 'col1module')
        else
          call add(blocks_stack, 'other')
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '@\@<!\<\%(while\|for\|\%(staged\)\?function\|macro\|begin\|type\|immutable\|let\|quote\|do\)\>', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(blocks_stack, 'other')
        continue
      endif

      " Note: it should be impossible to get here
      break

    else
      " The first occurrence is an 'end'

      let s = fe+1
      if len(blocks_stack) == 0
        let num_closed_blocks += 1
      else
        call remove(blocks_stack, -1)
      endif
      continue

    endif

    " Note: it should be impossible to get here
    break
  endwhile
  let num_open_blocks = len(blocks_stack) - count(blocks_stack, 'col1module')
  return [num_open_blocks, num_closed_blocks]
endfunction

function GetJuliaNestingBrackets(lnum, c)
  " Auxiliary function to inspect the block structure of a line
  let line = getline(a:lnum)[0 : (a:c - 1)]
  let s = 0
  let brackets_stack = []
  let num_closed_brackets = 0
  let last_closed_bracket = -1
  while 1
    let fb = JuliaMatch(a:lnum, line, '[([{]', s)
    let fe = JuliaMatch(a:lnum, line, '[])}]', s)

    if fb < 0 && fe < 0
      " No blocks found
      break
    end

    if fb >= 0 && (fb < fe || fe < 0)
      " The first occurrence is an opening bracket

      let i = JuliaMatch(a:lnum, line, '(', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(brackets_stack, ['par',i])
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '\[', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(brackets_stack, ['sqbra',i])
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '{', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(brackets_stack, ['curbra',i])
        continue
      endif

      " Note: it should be impossible to get here
      break

    else
      " The first occurrence is a closing bracket

      let i = JuliaMatch(a:lnum, line, ')', s)
      if i >= 0 && i == fe
        let s = i+1
        if len(brackets_stack) > 0 && brackets_stack[-1][0] == 'par'
          call remove(brackets_stack, -1)
        else
          let num_closed_brackets += 1
          let last_closed_bracket = i + 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, ']', s)
      if i >= 0 && i == fe
        let s = i+1
        if len(brackets_stack) > 0 && brackets_stack[-1][0] == 'sqbra'
          call remove(brackets_stack, -1)
        else
          let num_closed_brackets += 1
          let last_closed_bracket = i + 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '}', s)
      if i >= 0 && i == fe
        let s = i+1
        if len(brackets_stack) > 0 && brackets_stack[-1][0] == 'curbra'
          call remove(brackets_stack, -1)
        else
          let num_closed_brackets += 1
          let last_closed_bracket = i + 1
        endif
        continue
      endif

      " Note: it should be impossible to get here
      break

    endif

    " Note: it should be impossible to get here
    break
  endwhile
  let last_open_bracket = -1
  if len(brackets_stack) > 0
    let last_open_bracket = brackets_stack[-1][1]
  endif
  return [last_open_bracket, last_closed_bracket]
endfunction

let s:bracketBlocks = '\<julia\%(\%(\%(Printf\)\?Par\|SqBra\|CurBra\)Block\|ParBlockInRange\|StringVars\%(Par\|SqBra\|CurBra\)\)\>'

function IsInBrackets(lnum, c)
  let stack = map(synstack(a:lnum, a:c), 'synIDattr(v:val, "name")')
  call filter(stack, 'v:val =~# s:bracketBlocks')
  return len(stack) > 0
endfunction

" Auxiliary function to find a line which does not start in the middle of a
" multiline bracketed expression, to be used as reference for block
" indentation.
function LastBlockIndent(lnum)
  let lnum = a:lnum
  let ind = 0
  while lnum > 0
    let ind = indent(lnum)
    if ind == 0
      return [max([lnum,1]), 0]
    endif
    if !IsInBrackets(lnum, 1)
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return [max([lnum,1]), ind]
endfunction

function GetJuliaIndent()
  let s:save_ignorecase = &ignorecase
  set noignorecase

  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " At the start of the file use zero indent.
  if lnum == 0
    let &ignorecase = s:save_ignorecase
    unlet s:save_ignorecase
    return 0
  endif

  " Multiline bracketed expressions take precedence
  let c = len(getline(lnum)) + 1
  while IsInBrackets(lnum, c)
    let [last_open_bracket, last_closed_bracket] = GetJuliaNestingBrackets(lnum, c)

    " First scenario: the previous line has a hanging open bracket:
    " set the indentation to match the opening bracket (plus an extra space)
    if last_open_bracket != -1
      let ind = last_open_bracket + 1

    " Second scenario: some multiline bracketed expression was closed in the
    " previous line. But since we know we are still in a bracketed expression,
    " we need to find the line where the bracket was open
    elseif last_closed_bracket != -1 " && exists("loaded_matchit")
      " we use the % command to skip back (this is buggy without matchit, and
      " is potentially a disaster if % got remapped)
      call cursor(lnum, last_closed_bracket)
      normal %
      if line(".") == lnum
        " something wrong here, give up
        let ind = indent(lnum)
      else
        let lnum = line(".")
        let c = col(".") - 1
        if c == 0
          " uhm, give up
          let ind = 0
        else
          " we skipped a bracket set, keep searching for an opening bracket
          continue
        endif
      endif

    " Third scenario: nothing special, or matchit not available: keep the indentation
    else
      let ind = indent(lnum)
    endif

    " In case the current line starts with a closing bracket, we align it with
    " the opening one.
    if JuliaMatch(v:lnum, getline(v:lnum), '[])}]', indent(v:lnum)) == indent(v:lnum) && ind > 0
      let ind -= 1
    endif

    let &ignorecase = s:save_ignorecase
    unlet s:save_ignorecase
    return ind
  endwhile

  " We are not in a multiline bracketed expression. Thus we look for a
  " previous line to use as a reference
  let [lnum,ind] = LastBlockIndent(lnum)

  " Analyse the reference line
  let [num_open_blocks, num_closed_blocks] = GetJuliaNestingStruct(lnum)

  " Increase indentation for each newly opened block
  " in the reference line
  while num_open_blocks > 0
    let ind += &sw
    let num_open_blocks -= 1
  endwhile

  " Analyse the current line
  let [num_open_blocks, num_closed_blocks] = GetJuliaNestingStruct(v:lnum)

  " Decrease indentation for each closed block
  " in the current line
  while num_closed_blocks > 0
    let ind -= &sw
    let num_closed_blocks -= 1
  endwhile

  let &ignorecase = s:save_ignorecase
  unlet s:save_ignorecase
  return ind
endfunction
