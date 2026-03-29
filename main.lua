-- clobber
-- a combinatorial game

function _init()
 state=0 -- 0=title,1=mode,2=size,3=play,4=over
 gmode=0 -- 0=local,1=ai,2=online
 bw,bh=5,6
 msel=0 -- menu cursor
 turn=1 -- 1=black,2=white
 cx,cy=0,0
 sel=nil -- selected piece index
 board={}
 anim=nil -- animation state
 ai_co=nil -- ai coroutine
 ai_move=nil -- best move found
 ai_thinking=false
 ai_nodes=0
 ai_tick_t=0
 last_move=nil -- {fx,fy,tx,ty} for last move indicator
 flash=nil -- capture flash effect
end

-- board helpers
function bget(x,y)
 return board[y*bw+x+1]
end

function bset(x,y,v)
 board[y*bw+x+1]=v
end

function init_board()
 music(2) -- start game music
 board={}
 for y=0,bh-1 do
  for x=0,bw-1 do
   -- checkerboard: black(1) on even, white(2) on odd
   if (x+y)%2==0 then
    bset(x,y,1)
   else
    bset(x,y,2)
   end
  end
 end
 turn=1
 cx,cy=0,0
 sel=nil
 anim=nil
 ai_co=nil
 ai_move=nil
 ai_thinking=false
 last_move=nil
 flash=nil
end

-- cell size and offset for centering
function cell_info()
 local cs
 if bw==5 and bh==6 then
  cs=15
 else
  cs=13
 end
 local ox=flr((128-bw*cs)/2)
 local oy=flr((128-bh*cs)/2)+2 -- +2 for status bar
 return cs,ox,oy
end

-- check if a player has any legal move
function has_moves(p)
 local opp=3-p
 for y=0,bh-1 do
  for x=0,bw-1 do
   if bget(x,y)==p then
    if x>0 and bget(x-1,y)==opp then return true end
    if x<bw-1 and bget(x+1,y)==opp then return true end
    if y>0 and bget(x,y-1)==opp then return true end
    if y<bh-1 and bget(x,y+1)==opp then return true end
   end
  end
 end
 return false
end

-- check if move from (fx,fy) to (tx,ty) is legal
function is_legal(fx,fy,tx,ty)
 if tx<0 or tx>=bw or ty<0 or ty>=bh then return false end
 if abs(fx-tx)+abs(fy-ty)!=1 then return false end
 if bget(fx,fy)!=turn then return false end
 if bget(tx,ty)!=3-turn then return false end
 return true
end

-- get legal targets for piece at (x,y)
function get_targets(x,y)
 local t={}
 local opp=3-bget(x,y)
 if x>0 and bget(x-1,y)==opp then add(t,{x-1,y}) end
 if x<bw-1 and bget(x+1,y)==opp then add(t,{x+1,y}) end
 if y>0 and bget(x,y-1)==opp then add(t,{x,y-1}) end
 if y<bh-1 and bget(x,y+1)==opp then add(t,{x,y+1}) end
 return t
end

-- execute a move
function do_move(fx,fy,tx,ty)
 sfx(1) -- capture sound
 -- flash on captured square
 flash={x=tx,y=ty,t=0,dur=8}
 last_move={fx=fx,fy=fy,tx=tx,ty=ty}
 bset(tx,ty,bget(fx,fy))
 bset(fx,fy,0)
 turn=3-turn
 if not has_moves(turn) then
  winner=3-turn
  state=4
  music(-1) -- stop game music
  sfx(3) -- win fanfare
 end
end

-- gpio helpers (address 0x5f80 + pin)
function gpio_get(pin)
 return peek(0x5f80+pin)
end

function gpio_set(pin,val)
 poke(0x5f80+pin,val)
end

-- send move via gpio
function gpio_send_move(fx,fy,tx,ty)
 gpio_set(11,fx)
 gpio_set(12,fy)
 gpio_set(13,tx)
 gpio_set(14,ty)
 gpio_set(10,1) -- flag: new move
end

-- check for incoming move via gpio
function gpio_recv_move()
 if gpio_get(2)==1 then
  local fx=gpio_get(3)
  local fy=gpio_get(4)
  local tx=gpio_get(5)
  local ty=gpio_get(6)
  gpio_set(2,0) -- acknowledge
  return fx,fy,tx,ty
 end
 return nil
end

-- ai: count moves for player
function count_moves(p)
 local n=0
 local opp=3-p
 for y=0,bh-1 do
  for x=0,bw-1 do
   if bget(x,y)==p then
    if x>0 and bget(x-1,y)==opp then n+=1 end
    if x<bw-1 and bget(x+1,y)==opp then n+=1 end
    if y>0 and bget(x,y-1)==opp then n+=1 end
    if y<bh-1 and bget(x,y+1)==opp then n+=1 end
   end
  end
 end
 return n
end

-- ai: generate all moves for player p
function gen_moves(p)
 local moves={}
 local opp=3-p
 for y=0,bh-1 do
  for x=0,bw-1 do
   if bget(x,y)==p then
    if x>0 and bget(x-1,y)==opp then add(moves,{x,y,x-1,y}) end
    if x<bw-1 and bget(x+1,y)==opp then add(moves,{x,y,x+1,y}) end
    if y>0 and bget(x,y-1)==opp then add(moves,{x,y,x,y-1}) end
    if y<bh-1 and bget(x,y+1)==opp then add(moves,{x,y,x,y+1}) end
   end
  end
 end
 return moves
end

-- ai: minimax with alpha-beta
-- aip=ai's color, cp=current player
function minimax(depth,alpha,beta,cp,aip)
 local moves=gen_moves(cp)
 if #moves==0 then
  -- current player loses (no moves)
  if cp==aip then return -1000 end
  return 1000
 end
 if depth==0 then
  -- heuristic: mobility difference
  return count_moves(aip)-count_moves(3-aip)
 end

 if cp==aip then
  -- maximizing
  local best=-9999
  for m in all(moves) do
   -- make move
   local cap=bget(m[3],m[4])
   bset(m[3],m[4],bget(m[1],m[2]))
   bset(m[1],m[2],0)
   ai_nodes+=1
   if ai_nodes%50==0 then yield() end
   local score=minimax(depth-1,alpha,beta,3-cp,aip)
   -- unmake
   bset(m[1],m[2],bget(m[3],m[4]))
   bset(m[3],m[4],cap)
   if score>best then best=score end
   if best>alpha then alpha=best end
   if alpha>=beta then break end
  end
  return best
 else
  -- minimizing
  local best=9999
  for m in all(moves) do
   local cap=bget(m[3],m[4])
   bset(m[3],m[4],bget(m[1],m[2]))
   bset(m[1],m[2],0)
   ai_nodes+=1
   if ai_nodes%150==0 then yield() end
   local score=minimax(depth-1,alpha,beta,3-cp,aip)
   bset(m[1],m[2],bget(m[3],m[4]))
   bset(m[3],m[4],cap)
   if score<best then best=score end
   if best<beta then beta=best end
   if alpha>=beta then break end
  end
  return best
 end
end

-- start ai thinking
function start_ai()
 ai_thinking=true
 ai_move=nil
 ai_nodes=0
 ai_tick_t=0
 local aip=turn
 local depth=3
 if bw>=8 then depth=2 end
 ai_co=cocreate(function()
  local moves=gen_moves(aip)
  local best_score=-9999
  local best_m=moves[1]
  for m in all(moves) do
   local cap=bget(m[3],m[4])
   bset(m[3],m[4],bget(m[1],m[2]))
   bset(m[1],m[2],0)
   ai_nodes+=1
   local score=minimax(depth-1,-9999,9999,3-aip,aip)
   bset(m[1],m[2],bget(m[3],m[4]))
   bset(m[3],m[4],cap)
   if score>best_score then
    best_score=score
    best_m=m
   end
   yield()
  end
  ai_move=best_m
 end)
end

function _update()
 if state==0 then
  update_title()
 elseif state==1 then
  update_mode()
 elseif state==2 then
  update_size()
 elseif state==3 then
  update_play()
 elseif state==4 then
  update_over()
 end
end

-- title screen
function update_title()
 if not music_started then
  music(0)
  music_started=true
 end
 if btnp(4) or btnp(5) then
  sfx(0)
  state=1
  msel=0
 end
end

-- mode select
function update_mode()
 if btnp(2) then msel=max(0,msel-1); sfx(4) end
 if btnp(3) then msel=min(2,msel+1); sfx(4) end
 if btnp(4) then
  sfx(0)
  gmode=msel
  state=2
  msel=0
 end
 if btnp(5) then sfx(0); state=0 end
end

-- board size select
function update_size()
 if btnp(2) then msel=max(0,msel-1); sfx(4) end
 if btnp(3) then msel=min(1,msel+1); sfx(4) end
 if btnp(4) then
  sfx(0)
  if msel==0 then
   bw,bh=5,6
  else
   bw,bh=8,8
  end
  -- online: set board size gpio and request overlay
  if gmode==2 then
   gpio_set(16,msel) -- 0=5x6, 1=8x8
   gpio_set(15,1) -- waiting state
   gpio_set(20,1) -- show room overlay
  end
  init_board()
  state=3
 end
 if btnp(5) then sfx(0); state=1; msel=gmode end
end

-- gameplay
function update_play()
 -- online: check connection
 if gmode==2 then
  local conn=gpio_get(0)
  if conn==1 then
   -- waiting for opponent
   return
  elseif conn==3 then
   -- opponent disconnected
   state=4
   winner=gpio_get(1) -- we win by default
   return
  elseif conn!=2 then
   -- not connected yet, request overlay
   gpio_set(15,1) -- waiting
   gpio_set(20,1) -- show overlay
   return
  end
  -- connected: set my color from gpio
  my_color=gpio_get(1)
  gpio_set(20,2) -- hide overlay
  gpio_set(15,2) -- playing
 end

 -- flash effect
 if flash then
  flash.t+=1
  if flash.t>=flash.dur then flash=nil end
 end

 -- animation
 if anim then
  anim.t+=1
  if anim.t>=anim.dur then
   do_move(anim.fx,anim.fy,anim.tx,anim.ty)
   anim=nil
   -- start ai after player's move
   if state==3 and gmode==1 and turn==2 then
    start_ai()
   end
  end
  return
 end

 -- ai thinking
 if ai_thinking then
  ai_tick_t+=1
  if ai_tick_t%3==0 then sfx(5) end
  for i=1,8 do
   if costatus(ai_co)=="dead" then
    ai_thinking=false
    if ai_move then
     anim={fx=ai_move[1],fy=ai_move[2],
           tx=ai_move[3],ty=ai_move[4],
           t=0,dur=6}
    end
    break
   end
   coresume(ai_co)
  end
  return
 end

 -- if it's ai's turn and not yet thinking, start
 if gmode==1 and turn==2 and not ai_thinking then
  start_ai()
  return
 end

 -- online: opponent's turn - poll for incoming move
 if gmode==2 and turn!=my_color then
  local fx,fy,tx,ty=gpio_recv_move()
  if fx then
   anim={fx=fx,fy=fy,tx=tx,ty=ty,t=0,dur=6}
  end
  return
 end

 -- cursor movement
 if btnp(0) then cx=max(0,cx-1); sfx(4) end
 if btnp(1) then cx=min(bw-1,cx+1); sfx(4) end
 if btnp(2) then cy=max(0,cy-1); sfx(4) end
 if btnp(3) then cy=min(bh-1,cy+1); sfx(4) end

 if btnp(4) then -- confirm
  if sel then
   -- try to move selected piece to cursor
   local sx=sel[1]
   local sy=sel[2]
   if is_legal(sx,sy,cx,cy) then
    sfx(0) -- select/confirm
    -- start animation
    anim={fx=sx,fy=sy,tx=cx,ty=cy,t=0,dur=6}
    -- online: send move to opponent
    if gmode==2 then
     gpio_send_move(sx,sy,cx,cy)
    end
    sel=nil
   elseif bget(cx,cy)==turn then
    -- select different piece
    local t=get_targets(cx,cy)
    if #t>0 then
     sfx(0) -- select
     sel={cx,cy}
    else
     sfx(2) -- no moves
    end
   else
    sfx(2) -- invalid
    sel=nil
   end
  else
   -- select piece
   if bget(cx,cy)==turn then
    local t=get_targets(cx,cy)
    if #t>0 then
     sfx(0) -- select
     sel={cx,cy}
    else
     sfx(2) -- no moves
    end
   else
    sfx(2) -- wrong piece
   end
  end
 end

 if btnp(5) then -- cancel
  sel=nil
 end
end

-- game over
function update_over()
 if btnp(4) or btnp(5) then
  state=0
  msel=0
  music_started=false
 end
end

function _draw()
 cls(1)
 if state==0 then
  draw_title()
 elseif state==1 then
  draw_mode()
 elseif state==2 then
  draw_size()
 elseif state==3 then
  draw_play()
 elseif state==4 then
  draw_play()
  draw_over()
 end
end

function draw_title()
 -- animated decorative pieces
 local tt=t()
 for i=0,5 do
  local px=20+i*18
  local py=18+sin(tt*0.3+i*0.15)*4
  if i%2==0 then
   circfill(px,py,5,0)
   circ(px,py,5,5)
  else
   circfill(px,py,5,7)
   circ(px,py,5,6)
  end
 end

 -- title
 print("clobber",50,38,7)
 -- underline
 line(50,46,77,46,5)

 print("a combinatorial game",24,52,6)

 -- mode hints
 print("\x8e/\x97 to start",40,80,7)
 print("v1.0",56,120,5)
end

function draw_mode()
 print("select mode",42,20,7)
 local opts={"vs human","vs computer","online"}
 for i=0,2 do
  local c=6
  if i==msel then c=7 end
  local pre="  "
  if i==msel then pre="> " end
  print(pre..opts[i+1],38,44+i*12,c)
 end
 print("\x97 back",48,100,5)
end

function draw_size()
 print("board size",44,20,7)
 local opts={"5 x 6","8 x 8"}
 for i=0,1 do
  local c=6
  if i==msel then c=7 end
  local pre="  "
  if i==msel then pre="> " end
  print(pre..opts[i+1],46,50+i*12,c)
 end
 print("\x97 back",48,100,5)
end

function draw_play()
 local cs,ox,oy=cell_info()
 local pr=flr(cs/2)-2 -- piece radius

 -- status bar
 local tname
 if turn==1 then tname="black" else tname="white" end
 if gmode==2 and gpio_get(0)==1 then
  print("waiting for opponent...",2,2,7)
 elseif ai_thinking then
  local dots=sub("...",1,flr(ai_tick_t/5)%3+1)
  print(tname.." thinking"..dots,2,2,7)
 elseif gmode==2 and turn!=my_color then
  print("opponent's turn",2,2,7)
 else
  print(tname.."'s turn",2,2,7)
 end

 -- board frame
 rect(ox-1,oy-1,ox+bw*cs,oy+bh*cs,5)

 -- board background
 for y=0,bh-1 do
  for x=0,bw-1 do
   local sx=ox+x*cs
   local sy=oy+y*cs
   local bg=13
   if (x+y)%2==1 then bg=12 end
   rectfill(sx,sy,sx+cs-1,sy+cs-1,bg)
  end
 end

 -- last move indicator
 if last_move and not anim then
  local lx=ox+last_move.tx*cs
  local ly=oy+last_move.ty*cs
  rect(lx+1,ly+1,lx+cs-2,ly+cs-2,2)
 end

 -- legal move indicators (if piece selected)
 if sel and not anim then
  local targets=get_targets(sel[1],sel[2])
  for t in all(targets) do
   local sx=ox+t[1]*cs+flr(cs/2)
   local sy=oy+t[2]*cs+flr(cs/2)
   circfill(sx,sy,2,8)
  end
 end

 -- capture flash effect
 if flash then
  local fx=ox+flash.x*cs
  local fy=oy+flash.y*cs
  local fc=7
  if flash.t>flash.dur/2 then fc=6 end
  rectfill(fx,fy,fx+cs-1,fy+cs-1,fc)
 end

 -- pieces
 for y=0,bh-1 do
  for x=0,bw-1 do
   local v=bget(x,y)
   if v>0 then
    local sx=ox+x*cs+flr(cs/2)
    local sy=oy+y*cs+flr(cs/2)

    -- animated piece: interpolate position
    if anim and x==anim.fx and y==anim.fy then
     local p=anim.t/anim.dur
     local dx=(anim.tx-anim.fx)*cs*p
     local dy=(anim.ty-anim.fy)*cs*p
     sx+=dx
     sy+=dy
    end

    -- draw piece
    if v==1 then
     circfill(sx,sy,pr,0)
     circ(sx,sy,pr,0)
    else
     circfill(sx,sy,pr,7)
     circ(sx,sy,pr,7)
    end
   end
  end
 end

 -- selected highlight
 if sel and not anim then
  local sx=ox+sel[1]*cs
  local sy=oy+sel[2]*cs
  rect(sx,sy,sx+cs-1,sy+cs-1,11)
 end

 -- cursor
 if not anim then
  local sx=ox+cx*cs
  local sy=oy+cy*cs
  local fc=10
  if t()%0.5<0.25 then fc=9 end
  rect(sx,sy,sx+cs-1,sy+cs-1,fc)
 end

 -- piece counts
 local bc,wc=0,0
 for i=1,#board do
  if board[i]==1 then bc+=1
  elseif board[i]==2 then wc+=1
  end
 end
 local by=oy+bh*cs+3
 -- black score: count then circle (right-aligned to left edge)
 local bctxt=""..bc
 local bcw=#bctxt*4
 print(bctxt,ox-bcw-1,by,7)
 circfill(ox+2,by+2,2,0)
 circ(ox+2,by+2,2,5)
 -- white score: circle then count (left-aligned to right edge)
 circfill(ox+bw*cs-3,by+2,2,7)
 circ(ox+bw*cs-3,by+2,2,6)
 print(wc,ox+bw*cs+2,by,7)
end

function draw_over()
 local msg
 if winner==1 then
  msg="black wins!"
 else
  msg="white wins!"
 end
 if gmode==2 then
  if winner==my_color then
   msg="you win!"
  else
   msg="you lose!"
  end
 elseif gmode==1 then
  if winner==1 then
   msg="you win!"
  else
   msg="computer wins!"
  end
 end
 -- draw box behind text
 local tw=max(#msg*4,32)
 local bx1=63-tw/2-9
 local bx2=63+tw/2+9
 rectfill(bx1,48,bx2,78,0)
 rect(bx1,48,bx2,78,7)
 print(msg,64-#msg*2,54,7)
 print("\x8e/\x97 menu",44,68,6)
end
