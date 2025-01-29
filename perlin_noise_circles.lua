--------------------------------------------------------------------------------
-- perlin_noise_circles_accumulate.lua
-- フレームが進むとそれまでの円をそのまま保持しつつ、
-- 新たな円を加えていくスクリプト
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. 簡易的な 2D Perlin Noise 実装
--------------------------------------------------------------------------------
local permutation = {
  151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,
  140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,
  247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,
  32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,
  68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,
  111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,
  244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,
  187,208,89,18,169,200,196,135,130,116,188,159,86,164,100,
  109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,
  147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,
  182,189,28,42,223,183,170,213,119,248,152,2,44,154,163,
  70,221,153,101,155,167,43,172,9,129,22,39,253,19,98,
  108,110,79,113,224,232,178,185,112,104,218,246,97,228,251,
  34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,
  249,14,239,107,49,192,214,31,181,199,106,157,184,84,204,
  176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,
  67,29,24,72,243,141,128,195,78,66,215,61,156,180
}

local p = {}
for i=1, #permutation * 2 do
  p[i] = permutation[(i-1) % #permutation + 1]
end

local function fade(t)
  return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a, b, t)
  return a + t * (b - a)
end

local function grad(hash, x, y)
  local h = hash % 4
  local u = (h < 2) and x or y
  local v = (h < 2) and y or x
  local r1 = ((h % 2) == 0) and u or -u
  local r2 = ((math.floor(h/2) % 2) == 0) and v or -v
  return r1 + r2
end

local function perlin2d(x, y)
  local xi = math.floor(x) % 256
  local yi = math.floor(y) % 256
  local xf = x - math.floor(x)
  local yf = y - math.floor(y)

  local aa = p[p[xi + 1] + yi + 1]
  local ab = p[p[xi + 1] + (yi + 1) + 1]
  local ba = p[p[(xi + 1) + 1] + yi + 1]
  local bb = p[p[(xi + 1) + 1] + (yi + 1) + 1]

  local u = fade(xf)
  local v = fade(yf)

  local x1 = lerp(grad(aa, xf, yf),   grad(ba, xf - 1, yf),   u)
  local x2 = lerp(grad(ab, xf, yf-1), grad(bb, xf - 1, yf-1), u)
  local val = lerp(x1, x2, v)

  return val
end

--------------------------------------------------------------------------------
-- 2. 円を描画する関数
--------------------------------------------------------------------------------
local function drawFilledCircle(image, cx, cy, r, color)
  local minY = math.floor(cy - r)
  local maxY = math.floor(cy + r)
  for y = minY, maxY do
    local dy = y - cy
    for x = math.floor(cx - r), math.floor(cx + r) do
      local dx = x - cx
      if (dx*dx + dy*dy) <= r*r then
        if x >= 0 and x < image.width and y >= 0 and y < image.height then
          image:drawPixel(x, y, color)
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- 3. ダイアログ表示してパラメータ取得 -> スプライト生成
--------------------------------------------------------------------------------
local dlg = Dialog("Perlin Noise Circles (Accumulate)")
dlg:label{ text="キャンバスサイズ・フレーム数を指定してください。" }
dlg:entry{ id="width",   label="Width",   text="128" }
dlg:entry{ id="height",  label="Height",  text="128" }
dlg:entry{ id="frames",  label="Frames",  text="16" }

dlg:label{ text="円の最大半径、ノイズのスケールなどを設定できます。" }
dlg:entry{ id="radius",      label="Max Circle Radius", text="60" }
dlg:entry{ id="noiseScale",  label="Noise Scale",       text="0.01",
           tooltip="パーリンノイズの変化量" }
dlg:entry{ id="timeOffset",  label="Time Step",         text="0.05",
           tooltip="フレームや円ごとに増やす時間の刻み幅" }

dlg:button{ id="ok", text="OK" }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()

local data = dlg.data
if not data.ok then
  return
end

local width   = tonumber(data.width)
local height  = tonumber(data.height)
local frames  = tonumber(data.frames)
local maxRad  = tonumber(data.radius)
local nscale  = tonumber(data.noiseScale)
local tstep   = tonumber(data.timeOffset)

--------------------------------------------------------------------------------
-- 新規スプライトを作成（RGBA モード）
--------------------------------------------------------------------------------
local spr = Sprite(width, height, ColorMode.RGB)
spr.filename = "perlin_circles_accumulate.ase"

-- 必要なフレーム数に合わせて追加
if frames > 1 then
  for i = 2, frames do
    spr:newFrame()
  end
end

local black = Color{ r=0, g=0, b=0, a=255 }

--------------------------------------------------------------------------------
-- 4. フレームのループ
--    「前フレームの円を保持したまま」＋「フレーム f では f 個の新しい円を描画」
--------------------------------------------------------------------------------
for f = 1, frames do
  local cel = spr.cels[f]
  local image = cel.image

  -- (重要) もし f > 1 なら、前のフレームの画像をコピーしておく
  -- こうすることで、過去フレームの円をそのまま保持したまま上書きできる
  if f > 1 then
    local prevImage = spr.cels[f-1].image
    image:drawImage(prevImage)
  end

  -- フレーム f では、f個の円を追加で描画
  for i = 1, f do
    -- X, Y, R (半径) をそれぞれノイズで変動させる
    local circleTimeX = tstep * (f + i)
    local circleTimeY = tstep * (100 + f + i)
    local circleTimeR = tstep * (200 + f + i)

    local noiseValX = perlin2d(circleTimeX * nscale, circleTimeX * 0.5)
    local noiseValY = perlin2d(circleTimeY * 0.5,    circleTimeY * nscale)
    local noiseValR = perlin2d(circleTimeR * nscale, circleTimeR * nscale)

    local cx = (noiseValX + 1) / 2 * width
    local cy = (noiseValY + 1) / 2 * height
    local r  = 1 + ((noiseValR + 1) / 2) * (maxRad - 1)

    drawFilledCircle(image, cx, cy, r, black)
  end
end

app.refresh()
