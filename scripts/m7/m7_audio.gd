## M7 程序化音频。
## SFX（命中 / 跳跃 / 投出 / 必杀 / 拾取 / Boss 登场 / 结局等）与 BGM
## 全部由 AudioStreamGenerator 振荡器合成，零外部音频文件，
## 不含任何原作音频。参数与音符表来自 data/audio_m7.json。
## logic_only（headless 自测）下只做数据与调度计算，不创建音频节点。
extends Node
class_name M7Audio

const SAMPLE_RATE := 44100
const PI := 3.141592653589793

## SFX 播放器池（名称 -> AudioStreamPlayer）。
var sfx_players: Dictionary = {}
## BGM 播放器与调度状态。
var bgm_player: AudioStreamPlayer = null
var bgm_stage_id: String = ""
var bgm_schedule: Array = []
var bgm_index: int = 0
var bgm_timer: float = 0.0

## 构建音频节点（真实模式）。
func setup() -> void:
	if M7Data.logic_only:
		return
	for name in M7Data.audio().get("sfx", {}).keys():
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players[name] = p
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)

## 播放指定名称的 SFX。
func play_sfx(name: String) -> void:
	if M7Data.logic_only:
		return
	var p: AudioStreamPlayer = sfx_players.get(name)
	if p == null:
		return
	var cfg := M7Data.sfx(name)
	if cfg.is_empty():
		return
	p.stream = _make_sfx_stream(cfg)
	p.volume_db = float(cfg.get("volume_db", -6.0))
	p.play()

## 开始指定关卡的 BGM（计算调度；真实模式开始逐音播放）。
func start_bgm(stage_id: String) -> void:
	bgm_stage_id = stage_id
	bgm_schedule = bgm_schedule_for(stage_id)
	bgm_index = 0
	bgm_timer = 0.0

## 停止 BGM。
func stop_bgm() -> void:
	if M7Data.logic_only or bgm_player == null:
		return
	bgm_player.stop()

## 计算指定关卡的 BGM 调度（音符表 -> 频率 / 起始时间 / 时长）。
## 返回 [{note, freq, start, duration}]，rest 的 freq 为 0.0。
func bgm_schedule_for(stage_id: String) -> Array:
	var meta := M7Data.bgm_meta()
	var note_duration := float(meta.get("note_duration", 0.22))
	var stage_cfg := M7Data.bgm_stage(stage_id)
	var notes: Array = stage_cfg.get("notes", [])
	var out: Array = []
	var t := 0.0
	for n in notes:
		if n is Array and n.size() >= 2:
			var name := str(n[0])
			var beats := float(n[1])
			var dur := beats * note_duration
			out.append({"note": name, "freq": note_freq(name), "start": t, "duration": dur})
			t += dur
	return out

## BGM 推进（由 arena 每帧调用）。
func tick(dt: float) -> void:
	if M7Data.logic_only or bgm_player == null or bgm_schedule.is_empty():
		return
	bgm_timer += dt
	while bgm_index < bgm_schedule.size() and bgm_timer >= bgm_schedule[bgm_index].get("start", 0.0):
		var note: Dictionary = bgm_schedule[bgm_index]
		if note.get("freq", 0.0) > 0.0:
			bgm_player.stream = _make_note_stream(note.get("freq", 440.0), note.get("duration", 0.2))
			bgm_player.volume_db = -8.0
			bgm_player.play()
		bgm_index += 1
	if bgm_index >= bgm_schedule.size():
		if bool(M7Data.bgm_meta().get("loop", true)):
			bgm_index = 0
			bgm_timer = 0.0

## 音名转频率（科学音高记号，rest 返回 0.0）。C4 = 261.63Hz。
static func note_freq(name: String) -> float:
	if name == "rest" or name.is_empty():
		return 0.0
	var letter := name.substr(0, 1).to_lower()
	var octave_str := name.substr(1)
	var octave := int(octave_str) if octave_str.is_valid_int() else 4
	var semitone: int = 0
	match letter:
		"c": semitone = 0
		"d": semitone = 2
		"e": semitone = 4
		"f": semitone = 5
		"g": semitone = 7
		"a": semitone = 9
		"b": semitone = 11
		_: return 0.0
	var midi := (octave + 1) * 12 + semitone
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)

## 由 SFX 配置合成音频流。
func _make_sfx_stream(cfg: Dictionary) -> AudioStreamGenerator:
	var gen := AudioStreamGenerator.new()
	gen.sample_rate = SAMPLE_RATE
	if gen.has("buffer_length_msec"):
		gen.buffer_length_msec = max(float(cfg.get("duration", 0.1)) * 1000.0 + 100.0, 200.0)
	var playback: AudioStreamGeneratorPlayback = gen.playback
	playback.start()
	var duration := float(cfg.get("duration", 0.1))
	var freq := float(cfg.get("freq", 440.0))
	var freq_end := float(cfg.get("freq_end", freq))
	var attack := float(cfg.get("attack", 0.005))
	var wave := str(cfg.get("wave", "sine"))
	var total := int(SAMPLE_RATE * duration)
	for i in total:
		var t := float(i) / float(SAMPLE_RATE)
		var amp := 1.0
		if t < attack:
			amp = t / max(attack, 0.0001)
		else:
			var decay_t := t - attack
			amp = max(0.0, 1.0 - decay_t / max(duration - attack, 0.0001))
		var f: float = freq + (freq_end - freq) * (t / max(duration, 0.0001))
		var s := _wave(wave, amp * TAU * f * t)
		playback.push_frame(Vector2(s, s))
	return gen

## 由单音频率与时长合成音频流（BGM 音符）。
func _make_note_stream(freq: float, duration: float) -> AudioStreamGenerator:
	var gen := AudioStreamGenerator.new()
	gen.sample_rate = SAMPLE_RATE
	if gen.has("buffer_length_msec"):
		gen.buffer_length_msec = max(duration * 1000.0 + 100.0, 200.0)
	var playback: AudioStreamGeneratorPlayback = gen.playback
	playback.start()
	var total := int(SAMPLE_RATE * duration)
	for i in total:
		var t := float(i) / float(SAMPLE_RATE)
		var amp := sin(PI * t / max(duration, 0.0001))
		var sample := amp * sin(TAU * freq * t) * 0.6
		playback.push_frame(Vector2(sample, sample))
	return gen

## 波形生成。
static func _wave(wave: String, x: float) -> float:
	match wave:
		"square":
			return 1.0 if sin(x) > 0.0 else -1.0
		"sawtooth":
			var f: float = x / TAU - floor(x / TAU + 0.5)
			return f * 2.0
		"triangle":
			var f: float = x / TAU - floor(x / TAU + 0.5)
			return 2.0 * abs(f) - 1.0
		_:
			return sin(x)
