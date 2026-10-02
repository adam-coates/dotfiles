function! slime#targets#herdr#config() abort
  if !exists("b:slime_config")
    let b:slime_config = {}
  endif

  if !has_key(b:slime_config, "pane_id") || empty(b:slime_config.pane_id)
    " Find the pane to the right of the current one
    let l:current = $HERDR_PANE_ID
    if empty(l:current)
      let l:result = system("herdr pane current")
      let l:parsed = json_decode(l:result)
      let l:current = l:parsed.result.pane.pane_id
    endif

    let l:neighbor_json = system("herdr pane neighbor --current --direction right")
    let l:neighbor = json_decode(l:neighbor_json)
    if has_key(l:neighbor, "result") && has_key(l:neighbor.result, "pane")
      let b:slime_config.pane_id = l:neighbor.result.pane.pane_id
    else
      let b:slime_config.pane_id = input("herdr pane id: ", l:current)
    endif
  endif

  return b:slime_config
endfunction

function! slime#targets#herdr#send(config, text) abort
  let l:pane = a:config.pane_id
  call system(["herdr", "pane", "send-text", l:pane, a:text])
endfunction
