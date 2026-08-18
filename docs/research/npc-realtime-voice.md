# 实时语音与 TTS 如何驱动 NPC 的听、说与辅助动作

- Ticket: [#5](https://github.com/shenjunjian/ai-education/issues/5)
- 范围：事实与接口边界。不把「应该用哪家」写成创始决策。
- 方法：只引用厂商 Realtime/语音/TTS 文档、Web 标准、3D 运行时官方接口。

## 结论（可直接挂到地图）

**能。** 浏览器可以用 `getUserMedia` 采麦克风、用 WebRTC 或 WebSocket 把连续音频送进实时会话、再把模型/TTS 的音频播给学习者；3D NPC 的「开口」是播放这条音频，同时用**另一套、通常不同源的时间序列**去驱动网格（viseme ID、blendshape 权重、morph 权重、或骨骼姿态）。

三条不重叠的事实边界：

1. **听 + 开口回复**可以由「语音到语音（S2S）实时会话」单独完成，也可以由「流式 STT → 文本模型 → TTS」级联完成。前者厂商文档里是会话、VAD、打断、音频块与转写；后者把口型时间戳接到 TTS 事件上更容易。
2. **实时 S2S API 的公开事件面不包含 viseme / blendshape。** OpenAI Realtime 与 Gemini Live 文档列出的是音频、转写、工具调用、VAD/打断；Azure Neural TTS 才把 viseme ID、SVG、55 维 blendshape 与音频 offset 写成一等事件。
3. **3D 运行时不消费 viseme。** 它们消费 morph/blendshape 权重或骨骼变换。口型数据必须在应用层映射到网格上已存在、且同拓扑的目标（glTF morph targets、Three.js `morphTargetInfluences`、Babylon `MorphTarget.influence`、Unity `SetBlendShapeWeight`）。肢体动作是骨骼动画层，不是 viseme 的附带输出。

## 1. 「听」在浏览器里是什么

麦克风是 `MediaStream` 上的音频轨，不是语音语义。W3C *Media Capture and Streams* 把 `navigator.mediaDevices.getUserMedia` 定义为从麦克风等设备产生 `MediaStream` / `MediaStreamTrack`；消费者包括 `<audio>`、`RTCPeerConnection`、`MediaRecorder`、Web Audio 的 `MediaStreamAudioSourceNode`。[Media Capture and Streams](https://www.w3.org/TR/mediacapture-streams/)

WebRTC 的 `RTCPeerConnection` 用 `addTrack` 发送本地轨、用 `track` 事件接收远端轨；控制信令走应用自选通道（文档示例包括 WebSocket）。[WebRTC: Real-Time Communication in Browsers](https://www.w3.org/TR/2024/REC-webrtc-20241008/)

因此 NPC「听见学习者」= 应用把麦克风轨接到实时会话的输入侧。会话侧再决定何时算一轮用户话轮（VAD 或客户端按键）。

## 2. 可行的接口形态

下面是文档里实际存在的形态，不是选型。

### A. 语音到语音实时会话（一条连接里听并开口）

厂商把「低延迟语音代理」定义为保持打开的会话：客户端送音频/文本，服务端回音频、转写、工具调用、会话事件。

| 事实 | 来源 |
| --- | --- |
| OpenAI：Realtime 会话适合直播音频；voice-agent 会话在 `/v1/realtime` 上听、说、调工具；转写会话只出文本、不出口语回复；翻译会话是连续流、不用普通 assistant turn。 | [Realtime and audio](https://developers.openai.com/api/docs/guides/realtime) |
| 传输：浏览器/移动端用 WebRTC；服务端已有原始音频管道用 WebSocket；电话用 SIP。 | 同上 |
| WebRTC 下媒体由 peer connection 搬运；控制事件走 data channel（文档示例名 `oai-events`）。 | [Realtime API with WebRTC](https://developers.openai.com/api/docs/guides/realtime-webrtc) |
| 会话最长 **60 分钟**；`session.created` 后可用 `session.update`；模型一旦用某 `voice` 出过音频，该会话内语音不能再改。 | [Realtime conversations](https://developers.openai.com/api/docs/guides/realtime-conversations) |
| 默认开 VAD，自动判用户起止并回应；`turn_detection: null` 变成客户端提交缓冲 + `response.create`（按讲）。 | 同上 |
| 打断：VAD 开时，用户开说会取消进行中的回复。WebRTC/SIP 上服务端知道播了多少、会截断未播音频；WebSocket 客户端必须自己停播并按已播时长 truncate。事件：`input_audio_buffer.speech_started`、`response.cancelled`。 | 同上 |
| WebSocket 输出音频在 `response.output_audio.delta`（Base64 块）；`response.output_audio.done` / `response.done` **不含音频字节**。 | 同上 |
| 文档列出的增量事件是 `response.output_text.delta`、`response.output_audio.delta`、`response.output_audio_transcript.delta`。没有 viseme/phoneme/blendshape 事件名。 | [Realtime and audio](https://developers.openai.com/api/docs/guides/realtime) |
| Azure 上同一套 Realtime：WebRTC / WebSocket / SIP；厂商表格写 WebRTC「~100ms」、WebSocket「~200ms」（厂商声称，不是独立测量）。会话同样最长 60 分钟；`turn_detection` 为 `none` / `semantic_vad` / `server_vad`。 | [Azure realtime audio](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/realtime-audio) |
| Gemini Live：有状态 WebSocket；输入 PCM 16-bit / 16 kHz LE；输出 PCM 16-bit / 24 kHz LE。文档用例含「Interactive non-player characters (NPCs)」。 | [Gemini Live API overview](https://ai.google.dev/gemini-api/docs/live-api) |
| Gemini 默认识别说话人活动；打断时取消进行中的生成，服务端发 `BidiGenerateContentServerContent`。可配 `realtimeInputConfig.automaticActivityDetection`，或关掉后由客户端发 `activityStart` / `activityEnd`。 | [Live API capabilities](https://ai.google.dev/gemini-api/docs/live-api/capabilities) |
| Gemini 最佳实践：客户端必须在 `"interrupted": true` 时立刻丢掉本地播放缓冲。Session resumption token 在会话结束后有效 **2 小时**。建议音频块 20–40 ms。 | [Live API best practices](https://ai.google.dev/gemini-api/docs/live-api/best-practices) |
| Gemini 可开 `input_audio_transcription` / `output_audio_transcription`；文档描述的是转写文本，不是 viseme。 | [Live API capabilities](https://ai.google.dev/gemini-api/docs/live-api/capabilities) |

**边界：** 形态 A 足以让 NPC 听并开口。它**不**向 3D 运行时提供口型时间线。口型必须来自（i）对播放 PCM 做音频驱动 viseme，（ii）并行的 viseme TTS（会与 S2S 音色/时间线分裂），或（iii）粗能量驱动下颌。

### B. 级联：流式听写 + 文本回合 + TTS（含口型事件）

OpenAI 把架构拆开：请求式 API 用于文件/有界请求（文件转写、TTS）；Realtime 用于直播低延迟。[Audio and speech](https://developers.openai.com/api/docs/guides/audio)

TTS 端点接收文本，可流式返回音频（chunked transfer；`wav`/`pcm` 避免解码开销）。官方能力列表是音频格式与音色，不是 viseme。[Text to speech](https://developers.openai.com/api/docs/guides/text-to-speech)

Azure Neural TTS 明确把合成音频与面部姿态绑在一起：

- viseme = 音位在脸上的关键姿态；**音位与 viseme 不是 1:1**（如 `s`/`z` 共用一张嘴形）。
- 提供 **22** 个 viseme ID；每个事件带 `AudioOffset`，单位 tick（100 ns），文档示例除以 10 000 得毫秒。
- 2D：SVG；**SVG 仅 `en-US`**。
- 3D：`Animation` JSON；每帧 60 FPS、**55** 个 0–1 面部系数；引擎应在对应音频块**之前**渲染该组 `BlendShapes`；`FrameIndex` 是此前已发出的帧数。
- 只要 ID 时 `SpeakTextAsync` 即可；要 SVG/blendshape 须在 SSML 里用 `mstts:viseme`（`redlips_front` 或 `FacialExpression`）。
- 55 项顺序从 `eyeBlinkLeft` 到 `rightEyeRoll`，含 `jawOpen`、`mouth*`、`tongueOut` 以及 `headRoll` 等；这是面部系数，不是全身骨骼通道。

来源：[Get facial position with viseme](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-speech-synthesis-viseme)、[SSML viseme element](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup-voice#viseme-element)、[SpeechSynthesisVisemeEventArgs](https://learn.microsoft.com/en-us/dotnet/api/microsoft.cognitiveservices.speech.speechsynthesisvisemeeventargs)

词/句级手势时间戳是另一条事件：`SpeechSynthesisWordBoundaryEventArgs` 含 `AudioOffset`、`Duration`（tick）、`Text`、`TextOffset`、`BoundaryType`。[.NET API](https://learn.microsoft.com/en-us/dotnet/api/microsoft.cognitiveservices.speech.speechsynthesiswordboundaryeventargs)

Amazon Polly **speech marks** 是与音频对齐的 JSON 元数据（sentence / word / viseme / ssml）。文档写明：请求 speech marks 时 **返回元数据而不是合成语音**；口型应用要再请求一次音频并把 `time`（毫秒，相对音频起点）对齐播放时钟。[Speech marks](https://docs.aws.amazon.com/polly/latest/dg/speechmarks.html)、[Speech mark types](https://docs.aws.amazon.com/polly/latest/dg/using-speechmarks.html)、[Visemes and Amazon Polly](https://docs.aws.amazon.com/polly/latest/dg/viseme.html)

Google Cloud TTS 用 SSML `<mark>` + `TimepointType.SSML_MARK` 返回 `time_seconds`（相对音频起点的秒）。这是脚本锚点，不是 viseme 表。[SSML](https://docs.cloud.google.com/text-to-speech/docs/ssml)、[v1beta1 Timepoint](https://cloud.google.com/text-to-speech/docs/reference/rpc/google.cloud.texttospeech.v1beta1)

**边界：** 形态 B 把「说」和「口型时间线」放在同一 TTS 时钟上。端到端延迟是 STT 尾点 + 模型首 token + TTS 首音频之和；文档没有把这个和写成单一 SLA。打断要应用自己停 TTS、丢未播缓冲、决定是否把半句送回对话状态。

### C. Web Speech API（浏览器引擎，非云会话）

[Web Speech API](https://webaudio.github.io/web-speech-api/)（W3C Draft）分 `SpeechRecognition` 与 `SpeechSynthesis`。

合成事件：`start` / `end` / `error` / `pause` / `resume`；若引擎提供，还有 SSML `mark` 与 `boundary`。`boundary` 的 `name` 只能是 `"word"` 或 `"sentence"`。`elapsedTime` 相对本句开始（秒）；`charIndex` 只保证该下标之前已说、之后未说，**不保证落在词边界**。

**边界：** 可做听/说演示。规范**没有 viseme**。`boundary`/`mark` 依赖引擎，不能当成可移植口型时钟。

### D. 音频驱动 viseme（与 TTS 厂商无关）

Meta 把口型定义为对麦克风或**音频文件**流预测 viseme 权重，驱动网格 morph。一套 **15** 个目标：`sil, PP, FF, TH, DD, kk, CH, SS, nn, RR, aa, E, ih, oh, ou`（语言无关；文档指向 MPEG-4 FBA）。Oculus Lipsync 插件已 EOL；Movement SDK 经 `XR_META_face_tracking_visemes` 提供同一 15 个 viseme。运行时接口是 `GetViseme` / `VisemeDriver` 把权重绑到 SkinnedMesh blendshape。[Oculus Lipsync Unity](https://developers.meta.com/horizon/documentation/unity/audio-ovrlipsync-unity/)、[Viseme reference](https://developers.meta.com/horizon/documentation/native/audio-ovrlipsync-viseme-reference/)、[Movement SDK face tracking](https://developers.meta.com/horizon/documentation/unity/move-face-tracking/)

**边界：** 输入是 PCM，不是 viseme 事件。可套在任何 TTS/S2S 的播放缓冲上。得到的是口型权重，不是语义手势；身体动作仍要自己的动画状态机。

## 3. 延迟与会话模型（文档写明的）

| 对象 | 文档事实 |
| --- | --- |
| 请求式 vs 会话 | 有界请求（文件、整段 TTS）用 REST；直播听/说用长连接。[OpenAI audio](https://developers.openai.com/api/docs/guides/audio) |
| 话轮 | VAD 自动成轮，或客户端 `commit` + `response.create` / Gemini `activityEnd`。 |
| 打断 | 服务端取消生成；**客户端必须停本地播放**，否则 NPC 会盖过学习者（OpenAI WebSocket truncate；Gemini `interrupted`）。 |
| 会话寿命 | OpenAI/Azure Realtime：**60 分钟**，看 `expires_at` 再续。[Azure realtime](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/realtime-audio) Gemini resumption token：结束后 **2 小时**。[best practices](https://ai.google.dev/gemini-api/docs/live-api/best-practices) |
| 厂商延迟数字 | Azure 表：WebRTC ~100 ms、WebSocket ~200 ms。这是产品文档中的数量级，不是测量协议。 |
| TTS 流 | OpenAI Speech 用 chunked 编码，可在整文件完成前播放；低延迟格式 `wav`/`pcm`。[TTS](https://developers.openai.com/api/docs/guides/text-to-speech) |
| 口型时钟 | Azure viseme：tick；Polly：ms；Google mark：秒；Web Speech `elapsedTime`：秒。必须与**同一条**播放时钟对齐，不能混用两路合成。 |

英语教学模式里「学习者随时打断 NPC」依赖 VAD/barge-in **加上** 3D 层在取消事件上把口型权重打回静音 viseme（Azure ID 0 / Meta `sil`），否则嘴还会跟着已取消的音频动。

## 4. 动作驱动的事实边界

### 口型不是骨骼

Viseme 描述唇/颌/舌的可见姿态。Azure 55 维 blendshape 是面部系数列表；其中 `headRoll` 等是头，不是手臂/脊柱。全身动作走 glTF / 引擎的骨骼通道（`JOINTS_0`/`WEIGHTS_0`、skin、AnimationMixer、Animator），与 viseme 事件正交。[glTF 2.0 Morph Targets](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)（规范 §3.7.2.2）

### 3D 运行时吃权重，不吃 viseme ID

| 运行时 | 接口 | 来源 |
| --- | --- | --- |
| glTF 2.0 | primitive `targets` 存位移；`mesh.weights` / `node.weights` 做加权和。动画 `channel.target.path` 可为 `"weights"`。 | [Khronos tutorial](https://github.com/KhronosGroup/glTF-Tutorials/blob/main/gltfTutorial/gltfTutorial_017_SimpleMorphTarget.md)、[Object Model](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/ObjectModel.adoc) |
| three.js | `Mesh.morphTargetInfluences`：通常 `[0,1]` 的权重数组；无 morph 时为 `undefined`。 | [Mesh](https://threejs.org/docs/#api/en/objects/Mesh) |
| Babylon.js | `MorphTargetManager` + `target.influence`；网格与所有 target **顶点数必须相同**。 | [Morph Targets](https://doc.babylonjs.com/features/featuresDeepDive/mesh/morphTargets) |
| Unity | `SkinnedMeshRenderer.SetBlendShapeWeight(index, value)`；手册示例 0 = 无影响、100 = 满影响。 | [SetBlendShapeWeight](https://docs.unity3d.com/ScriptReference/SkinnedMeshRenderer.SetBlendShapeWeight.html)、[Blend shapes](https://docs.unity3d.com/6000.7/Documentation/Manual/BlendShapes.html) |
| ARKit | `ARFaceAnchor.blendShapes`：特征名 → 0.0–1.0。用于跟踪真人脸驱动角色，**不是 TTS viseme 表**。 | [blendShapes](https://developer.apple.com/documentation/arkit/arfaceanchor/blendshapes) |

Azure 的 22 个 ID、Polly 的 viseme 符号、Meta 的 15 个 MPEG-4 名、ARKit 的 50+ 系数 **彼此不是同一套枚举**。映射表是资产管线的一部分，不是语音 API 的一部分。网格缺少对应 morph 时，事件无法显示。

### 时间戳契约

要嘴型贴音频，必须满足：

1. 事件时间相对**正在播放的那条** PCM/容器的 0 点（Azure tick、Polly ms、Google s）。
2. 渲染调度用播放时钟（`AudioContext.currentTime`、WebRTC 远端轨、引擎 `AudioSource.time`），不是网络到达时间。Azure 要求一组 blendshape **先于**对应音频块绘制。
3. 打断后：停音频、把权重收到静音、丢掉未播 viseme 队列。S2S 文档要求停音频；viseme 队列是应用状态，API 不会清。
4. 词边界事件适合字幕/点头/手势触发，粒度是词/句，不是音位嘴型。

### 辅助肢体动作

文档提供的挂钩：

- **词/句/SSML mark 时间**（Azure WordBoundary、Polly word/ssml marks、Google `<mark>`、Web Speech `boundary`/`mark`）→ 在时间 T 触发 AnimationClip / 手势状态。
- **会话生命周期**（`speech_started` / `speech_stopped`、Gemini interrupted、回复完成）→ 听/说/待机动画，不是逐帧口型。
- **骨骼**由运行时动画系统驱动；语音 API 不输出关节角。

没有厂商把「挥手」编码进 viseme 流。

## 5. 对英语模式 3D NPC 的含义（仍非选型）

产品要同时满足「听学习者」「开口回复」「口型/肢体」时，文档允许的组合是：

- **听+说：** 形态 A（S2S 会话）或形态 B/C（STT + TTS）。A 的会话/打断模型是现成的；B 把 viseme 时钟和语音绑在同一 TTS 上。
- **口型：** 若走 A，S2S 事件面不够驱动 viseme；需音频驱动 viseme（形态 D）或第二路 viseme TTS（两路时钟）。若走 B 且 TTS 为 Azure viseme / Polly speech marks，口型是一等数据。
- **肢体：** 用词边界或会话阶段触发骨骼动画；不要等 viseme API 长出身体通道。

「用哪家」不在本笔记决定。上面每一条都只约束接口形态与时间线，不约束供应商。

## 来源

- https://developers.openai.com/api/docs/guides/realtime
- https://developers.openai.com/api/docs/guides/realtime-webrtc
- https://developers.openai.com/api/docs/guides/realtime-conversations
- https://developers.openai.com/api/docs/guides/audio
- https://developers.openai.com/api/docs/guides/text-to-speech
- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/realtime-audio
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-speech-synthesis-viseme
- https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup-voice
- https://learn.microsoft.com/en-us/dotnet/api/microsoft.cognitiveservices.speech.speechsynthesisvisemeeventargs
- https://learn.microsoft.com/en-us/dotnet/api/microsoft.cognitiveservices.speech.speechsynthesiswordboundaryeventargs
- https://ai.google.dev/gemini-api/docs/live-api
- https://ai.google.dev/gemini-api/docs/live-api/capabilities
- https://ai.google.dev/gemini-api/docs/live-api/best-practices
- https://ai.google.dev/api/live
- https://docs.cloud.google.com/text-to-speech/docs/ssml
- https://cloud.google.com/text-to-speech/docs/reference/rpc/google.cloud.texttospeech.v1beta1
- https://docs.aws.amazon.com/polly/latest/dg/speechmarks.html
- https://docs.aws.amazon.com/polly/latest/dg/using-speechmarks.html
- https://docs.aws.amazon.com/polly/latest/dg/viseme.html
- https://webaudio.github.io/web-speech-api/
- https://www.w3.org/TR/mediacapture-streams/
- https://www.w3.org/TR/2024/REC-webrtc-20241008/
- https://developers.meta.com/horizon/documentation/unity/audio-ovrlipsync-unity/
- https://developers.meta.com/horizon/documentation/native/audio-ovrlipsync-viseme-reference/
- https://developers.meta.com/horizon/documentation/unity/move-face-tracking/
- https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
- https://github.com/KhronosGroup/glTF-Tutorials/blob/main/gltfTutorial/gltfTutorial_017_SimpleMorphTarget.md
- https://threejs.org/docs/#api/en/objects/Mesh
- https://doc.babylonjs.com/features/featuresDeepDive/mesh/morphTargets
- https://docs.unity3d.com/ScriptReference/SkinnedMeshRenderer.SetBlendShapeWeight.html
- https://docs.unity3d.com/6000.7/Documentation/Manual/BlendShapes.html
- https://developer.apple.com/documentation/arkit/arfaceanchor/blendshapes
