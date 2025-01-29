--------------------------------------------------------------------------------
-- パーリンノイズに従い、フレームごとに黒い円を描画する
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. パーリンノイズ実装 (2D版)
-- Luaでの一般的なPerlin Noise実装の簡易例
--------------------------------------------------------------------------------

-- パーマネーションテーブルの準備
-- （0〜255までのランダムな順列テーブルを2回連結する）
local permutation = {
    151,160,137,91,90,15,
    131,13,201,95,96,53,194,233,7,225,
    140,36,103,30,69,142,8,99,37,240,
    21,10,23,190, 6,148,247,120,234,75,
    0,26,197,62,94,252,219,203,117,35,
    11,32,57,177,33,88,237,149,56,87,
    174,20,125,136,171,168, 68,175,74,
    165,71,134,139,48,27,166,77,146,158,
    231,83,111,229,122,60,211,133,230,220,
    105,92,41,55,46,245,40,244,102,143,
    54, 65,25,63,161, 1,216,80,73,209,
    76,132,187,208, 89,18,169,200,196,135,
    130,116,188,159,86,164,100,109,198,173,
    186, 3,64,52,217,226,250,124,123, 5,
    202,38,147,118,126,255,82,85,212,207,
    206,59,227,47,16,58,17,182,189,28,
    42,223,183,170,213,119,248,152, 2,44,
    154,163, 70,221,153,101,155,167, 43,
    172, 9,129,22,39,253, 19,98,108,
    110,79,113,224,232,178,185, 112,104,
    218,246,97,228,251,34,242,193,238,210,
    144,12,191,179,162,241, 81,51,145,
    235,249,14,239,107, 49,192,214, 31,
    181,199,106,157,184, 84,204,176,115,
    121, 50,45,127,  4,150,254,138,236,
    205, 93,222,114, 67,29, 24,72,243,
    141,128,195,78,66,215,61,156,180
  }
  
  local p = {}
  -- permutationテーブルを2回つなげて 0~511 にする
  for i=1, #permutation*2 do
    p[i] = permutation[(i-1) % #permutation + 1]
  end
  
  -- fade関数: スムーズな補間のためのイージング関数
  local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
  end
  
  -- 線形補間
  local function lerp(a, b, t)
    return a + t * (b - a)
  end
  
  -- 勾配ベクトルによる値算出
  -- Perlinの各グリッド点からのベクトルで値が変わる
  local function grad(hash, x, y)
    -- 下位2bitで方向を決める簡易実装
    local h = hash % 4
    local u = (h < 2) and x or y
    local v = (h < 2) and y or x
    local r1 = ((h % 2) == 0) and u or -u
    local r2 = ((math.floor(h/2) % 2) == 0) and v or -v
    return r1 + r2
  end
  
  -- 2次元パーリンノイズ関数
  -- x, y は連続値。戻り値は -1 ~ +1 を想定
  local function perlin2d(x, y)
    -- 小数点以下と整数部分を分ける
    local xi = math.floor(x) % 256
    local yi = math.floor(y) % 256
    local xf = x - math.floor(x)
    local yf = y - math.floor(y)
  
    -- 各頂点の乱数テーブル参照用のハッシュ
    local aa = p[p[xi + 1] + yi + 1]
    local ab = p[p[xi + 1] + (yi + 1) + 1]
    local ba = p[p[(xi + 1) + 1] + yi + 1]
    local bb = p[p[(xi + 1) + 1] + (yi + 1) + 1]
  
    -- fadeで補間用ウェイト作成
    local u = fade(xf)
    local v = fade(yf)
  
    -- 4つのコーナーでの値を線形補間
    local x1 = lerp(grad(aa, xf, yf),   grad(ba, xf - 1, yf),   u)
    local x2 = lerp(grad(ab, xf, yf-1), grad(bb, xf - 1, yf-1), u)
    local val = lerp(x1, x2, v)
  
    return val  -- -1 ~ +1
  end
  
  --------------------------------------------------------------------------------
  -- 2. 円を描画する
  --------------------------------------------------------------------------------
  -- imageに対して (cx, cy) 中心、半径 r の塗りつぶし円を描画
  -- (cx, cy) は整数でなくても良いが、ピクセルとしては切り捨てられる
  --------------------------------------------------------------------------------
  local function drawFilledCircle(image, cx, cy, r, color)
    local minY = math.floor(cy - r)
    local maxY = math.floor(cy + r)
    local minX, maxX
    for y = minY, maxY do
      local dy = y - cy
      for x = math.floor(cx - r), math.floor(cx + r) do
        local dx = x - cx
        if (dx*dx + dy*dy) <= r*r then
          -- キャンバス外に出ないようチェック
          if (x >= 0) and (x < image.width) and (y >= 0) and (y < image.height) then
            image:drawPixel(x, y, color)
          end
        end
      end
    end
  end
  
  --------------------------------------------------------------------------------
  -- 3. メイン処理: ダイアログを出してパラメータを取得し、スプライトを生成
  --    フレームごとにパーリンノイズを使って黒い円を描画
  --------------------------------------------------------------------------------
  local dlg = Dialog("Perlin Noise Circles")
  
  dlg:label{ text="キャンバスサイズ・フレーム数を指定してください。" }
  dlg:entry{ id="width",   label="Width",   text="128" }
  dlg:entry{ id="height",  label="Height",  text="128" }
  dlg:entry{ id="frames",  label="Frames",  text="16" }
  
  dlg:label{ text="円の半径、ノイズのスケールなどを設定できます。" }
  dlg:entry{ id="radius",      label="Circle Radius", text="16" }
  dlg:entry{ id="noiseScale",  label="Noise Scale",   text="0.1",
             tooltip="パーリンノイズに掛ける倍率が大きいほど動きが激しくなる" }
  dlg:entry{ id="timeOffset",  label="Time Step",     text="0.5",
             tooltip="フレームごとにノイズのx, yに足す値。アニメの動き具合を調整" }
  
  dlg:button{ id="ok", text="OK" }
  dlg:button{ id="cancel", text="Cancel" }
  dlg:show()
  
  local data = dlg.data
  if not data.ok then
    return -- キャンセルした場合はスクリプト終了
  end
  
  local width   = tonumber(data.width)
  local height  = tonumber(data.height)
  local frames  = tonumber(data.frames)
  local radius  = tonumber(data.radius)
  local nscale  = tonumber(data.noiseScale)
  local tstep   = tonumber(data.timeOffset)
  
  -- 新規スプライト作成（RGBAモード）
  local spr = Sprite(width, height, ColorMode.RGB)
  spr.filename = "perlin_circles.ase"
  
  -- フレーム数を追加
  -- デフォルトで1フレーム目はもうあるので、(frames-1)枚追加
  if frames > 1 then
    spr.frames = frames
  end
  
  -- 黒色（RGBA）を作成
  local black = Color{ r=0, g=0, b=0, a=255 }
  
  -- フレームごとに円を描画
  -- time 変数が増えていくのに合わせてノイズを計算し、座標を決定
  local time = 0.0
  for f = 1, frames do
    -- 各フレームのCelを取得
    local cel = spr.cels[f]
    local image = cel.image
  
    -- パーリンノイズによる中心座標の計算 (0〜1に正規化するため +1)/2 する
    -- 例: xCoord = ((perlin2d(time, 0) + 1) / 2) * width
    local noiseX = perlin2d(time * nscale, 10.0)  -- 適当に 10.0 を足すとY変化とズラせる
    local noiseY = perlin2d(20.0, time * nscale) -- X変化とズラすために 20.0 を使用
    local cx = (noiseX + 1) / 2 * width
    local cy = (noiseY + 1) / 2 * height
  
    -- 円を描画
    drawFilledCircle(image, cx, cy, radius, black)
  
    -- スプライト更新
    spr.cels[f].image = image
    
    -- time を進める
    time = time + tstep
  end
  
  app.refresh()