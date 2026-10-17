# audio-source — 사운드 편집 원본

DAW 세션·녹음 원본(WAV)을 둔다. 게임에 들어가는 것은 `godot/assets/audio/` 로 내보낸 OGG 다.

```
audio-source/
  music/     # DAW 세션, 마스터 WAV
  sfx/       # 원본 WAV (44.1kHz/48kHz, 16·24bit)
  voice/
```

## 규칙

1. **납품은 OGG Vorbis.** 변환은 ffmpeg 로 통일한다.
   ```bash
   ffmpeg -i in.wav -c:a libvorbis -q:a 5 godot/assets/audio/sfx/in.ogg
   ```
   Godot은 WAV도 읽지만 용량이 크다. 짧은 SFX는 WAV, 긴 음악·앰비언스는 OGG가 실용적이다.
2. **루프 지점은 파일에 심지 말고 임포트 설정에 남긴다.** Godot의 `.import` 에 loop 옵션이 있고,
   그 파일이 커밋 대상이다. 원본 WAV를 다시 뽑아도 루프 설정이 유지된다.
3. **원본은 자르지 않는다.** 페이드·정규화는 내보낼 때 적용하고, 원본은 그대로 보관한다.
4. 믹싱 기준(음량 목표, 우선순위, 동시 발음 수)은 이 문서가 아니라
   [docs/audio/AUDIO_GUIDE.md](../docs/audio/AUDIO_GUIDE.md) 가 정본이다.

## 아직 없는 것

오디오는 **하나도 없다.** 사운드 시스템도 아직 없다 — 지금은 조용한 스캐폴드다.
