# ADR 0004 — 렌더러는 `gl_compatibility` 고정

## 맥락

이 프로젝트는 Intel iMac(macOS 12, AMD Radeon R9 M390)에서 개발한다. macOS는 Vulkan을 네이티브로
제공하지 않아 Forward+와 Mobile 렌더러는 MoltenVK를 거친다. 이 조합에서 검은 화면·Vulkan device loss
보고가 있고, 그 경로를 피하는 것이 목표였다.

## 대안

1. **Forward+** — 최신 기능(SDFGI, SSR, 볼류메트릭 포그, 데칼, 컴퓨트 셰이더)을 전부 쓴다.
   이 머신에서 검은 화면 위험이 있고, 확인되면 개발 자체가 막힌다.
2. **Mobile** — Forward+보다 가볍지만 같은 MoltenVK 경로를 탄다.
3. **Compatibility(OpenGL 3.3)** — Vulkan 경로를 아예 쓰지 않는다. 기능은 줄어든다.

## 결정

3번. `project.godot` 에서 데스크톱·모바일 모두 `gl_compatibility` 로 고정한다.

**못 쓰는 것**: SDFGI, VoxelGI, SSIL, SSR, 볼류메트릭 포그, 서브서피스 스캐터링, 데칼, DOF,
컴퓨트 셰이더, TAA/FSR2/FXAA/SMAA. 라이트맵 **베이킹**도 RenderingDevice가 필요해 불가(베이킹된 라이트맵의 렌더링은 가능).

**쓸 수 있는 것**: SSAO, MSAA 3D, SSAA, 기본 depth/height fog, glow.

## 결과

**얻은 것**
- 이 머신에서 실제로 렌더가 돈다. OpenGL 4.1 컨텍스트로 프레임이 나오는 것을 확인했다 (자체 실측).
- 헤드리스 테스트와 실제 렌더가 같은 렌더러를 쓴다. CI와 눈으로 보는 것이 갈라지지 않는다.

**잃은 것**
- 위에 적은 기능을 설계에서 빼야 한다. 특히 라이트맵 베이킹이 안 되므로 조명은 실시간 + SSAO 중심으로 간다.
- 나중에 Forward+로 올리려면 조명·후처리 설정을 다시 잡아야 한다. 그래서 이 결정을 여기 남긴다.

**되돌리는 조건**
- 개발 기기가 Vulkan 네이티브 환경(Windows/Linux 또는 Apple Silicon + 최신 Godot)으로 바뀌고,
  대상 플레이어 기기의 하한이 올라갈 때. 그때는 이 ADR을 대체하는 새 ADR을 쓴다.
