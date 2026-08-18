# GeoGebra：命令驱动可拖动图形（调研）

对应票：[issue #4](https://github.com/shenjunjian/ai-education/issues/4)。问题：开源 GeoGebra 组件能否承接「把 GeoGebra 命令发给组件，渲染公式与图形，且点、线可被学习者拖动」；许可证是否允许用在本产品；做不到的边界。

调研日期：2026-08-18。只使用官方手册、官方嵌入/API 文档、官方仓库源代码、许可证/ToS 原文、EUR-Lex 上的 EUPL 文本。

**结论（技术）**：可以。官方嵌入路径是网页里 `deployggb.js` / `GGBApplet` 注入，或 ES6 `mathApps` 模块；产品侧把「GeoGebra 命令」字符串交给 `evalCommand`（等价于输入栏）。`A=(1,1)` 这类直接输入会得到**可拖动的自由点**；`Line(A,B)` 得到**依赖直线**（随端点拖动而更新）。固定对象、依赖对象、以及未开工具栏时的交互限制见下文边界。

**结论（许可证）**：直接用官方 CDN / 安装包 / 语言文件 / 材料平台，默认只覆盖**非商业**用途；本产品若收取学费、订阅费或作为商业产品，官方要求与 `office@geogebra.org` 签订商业 License and Collaboration Agreement。源码本身是 **EUPL v1.2**（可商业使用，但有 copyleft / 源码提供义务），且**不得**把源码与官方 Materials / Language Files 拼成完整 GeoGebra 产品后仍按非商业条款以外的方式使用。以下不是法律意见。

---

## 1. 如何嵌入 / 部署

### 1.1 网页组件（官方推荐）

官方嵌入文档要求：viewport/charset、引入 `https://www.geogebra.org/apps/deployggb.js`、页面上放一个容器 `div`，然后 `new GGBApplet(params, true)` 并 `inject`。[GeoGebra Apps Embedding](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_Embedding/)

`appName` 可选：`graphing`、`geometry`、`3d`、`classic`、`suite`、`evaluator`、`scientific`、`notes`（默认 `classic`）。可用 `material_id`、`filename`、`ggbBase64` 加载已有活动。[GeoGebra App Parameters](https://geogebra.github.io/docs/reference/en/GeoGebra_App_Parameters/)

官方建议优先走 `www.geogebra.org` 的 CDN；也可下载 **GeoGebra Math Apps Bundle** 自托管：把 `deployggb.js` 改成本地路径，并在 `inject` 前 `applet.setHTML5Codebase('GeoGebra/HTML5/5.0/web3d/')`。也可把 codebase 钉到 CDN 上的具体版本（911 之后要用 `5.4` 而不是 `5.0`）。[GeoGebra Apps Embedding — Offline and Self-Hosted](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_Embedding/)

源码仓库是官方 math apps 的镜像，用 Gradle 可在本机跑 web / desktop 开发服务器。[geogebra/geogebra README](https://raw.githubusercontent.com/geogebra/geogebra/master/README.md)

### 1.2 ES6 模块

官方 API 文档提供 `mathApps` 模块：

```js
import {mathApps} from 'https://www.geogebra.org/apps/latest/web3d/web3d.nocache.mjs';
mathApps.create({'appName':'graphing'})
  .inject(document.querySelector("#plot"))
  .getAPI().then(api => api.evalCommand('f(x)=sin(x)'));
```

[GeoGebra Apps API — Obtaining the API Object as a module](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

### 1.3 iframe（材料嵌入，不适合本产品主路径）

iframe 面向「把已发布的 GeoGebra 材料嵌进网站」：`https://www.geogebra.org/material/iframe/id/...`。官方写明：若需要额外定制、JavaScript API 或离线支持，应改用 Math Apps Embedding。iframe 灵活性差，且在 iOS 上未完全支持。[Material Embedding (Iframe)](https://geogebra.github.io/docs/reference/en/Material_Embedding_(Iframe)/)；[integration: basic-embedding-options](https://geogebra.github.io/integration/basic-embedding-options.html)

本产品要把命令发给组件并读回拖动状态，应使用 **div 注入 + Apps API**，不要用材料 iframe。

### 1.4 独立 App / 桌面

官方提供各平台计算器与 Classic 安装包。[GeoGebra download](https://www.geogebra.org/download)。仓库也可 `./gradlew -p source/desktop :desktop:run` 跑 Classic 5。[README](https://raw.githubusercontent.com/geogebra/geogebra/master/README.md)

安装包属于许可证里的 **Materials / installers**（见第 4 节），不是本产品画布嵌入的首选形态。

### 1.5 拿到 API 对象

- `appletOnLoad(api) { ... }`（`GGBApplet` 参数）
- 全局 `ggbApplet`（多实例时指向最后活动的那个；应用 `id` 参数区分）
- `mathApps.create(...).inject(...).getAPI()`

[GeoGebra Apps API — Obtaining the API Object](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

---

## 2. 命令 / API 语言是什么

不是单一语言，而是三层，产品应把「GeoGebra 命令」对准**输入栏语言**，用 JS 的 `evalCommand` 投递。

### 2.1 输入栏代数式 + GeoGebra Commands（产品主路径）

`evalCommand(String cmdString)`：**把字符串当作输入栏内容求值**；返回是否成功；可用 `\n` 一次传多条；**必须使用英文命令名**。[GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

源码接口注释与文档一致：*Evaluates the given string as if it was entered into GeoGebra's input text field.* [JavaScriptAPI.java](https://github.com/geogebra/geogebra/blob/master/common/src/main/java/org/geogebra/common/plugin/JavaScriptAPI.java)

输入栏官方例子（与 `evalCommand` 同源语义）：

- `f(x) = x^2` → 代数视图中的函数 + 图形视图中的图像
- `A=(1,1)`、`B=(3,4)` → 自由点
- `Line(A, B)` → 过两点的依赖直线

[Input Bar](https://geogebra.github.io/docs/manual/en/Input_Bar/)；[Points and Vectors](https://geogebra.github.io/docs/manual/en/Points_and_Vectors/)（`P = (1, 0)`）

相关 API：

| 方法 | 作用 | 来源 |
| --- | --- | --- |
| `evalCommandGetLabels` | 同 `evalCommand`，返回新建对象标签，如 `"A,B,C"` | [Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/) |
| `evalLaTeX` / `evalLaTex` | 把 LaTeX 求值为作图元素（`\sqrt`、`\frac` 等） | 同上 |
| `evalCommandCAS` | 交给 CAS，返回字符串结果 | 同上 |
| `appletOnLoad` 示例 | `api.evalCommand('Segment((1,2),(3,4))')` | [App Parameters](https://geogebra.github.io/docs/reference/en/GeoGebra_App_Parameters/) |

### 2.2 GGBScript（对象上的脚本，不是宿主投递通道）

GeoGebra 支持两种脚本语言：**GGBScript** 和 **JavaScript**。GGBScript 就是一串按输入栏写法排列的 GeoGebra 命令，挂在对象的 OnClick / OnUpdate / OnChange / On Drag-end 等标签上。[Scripting](https://geogebra.github.io/docs/manual/en/Scripting/)

产品从外部「发命令」应走 `evalCommand`，不必把宿主逻辑写成 GGBScript。GGBScript 适合构造内部交互（例如拖滑块改颜色）。

### 2.3 JavaScript（`ggbApplet` 方法）

对象脚本或宿主页面可调用 `ggbApplet.method_name(...)`，完整列表即 Apps API。官方示例用循环 `evalCommand("A_"+i+"=(random()*10,random()*10)")` 建点。[Scripting — JavaScript](https://geogebra.github.io/docs/manual/en/Scripting/)

这是**宿主控制面**，不是学习者看到的「GeoGebra 命令」语言本身。

### 2.4 XML / `.ggb`（状态序列化，不是命令语言）

`.ggb` 是 ZIP；其中 `geogebra.xml` 存构造。[File Format](https://wiki.geogebra.org/en/Reference:File_Format)；[XML](https://wiki.geogebra.org/en/Reference:XML)（XSD：`http://geogebra.org/ggb.xsd`）

API：`getXML` / `setXML`（先清空再加载）/ `evalXML`（不清空）/ `getBase64` / `setBase64` / `getFileJSON` / `setFileJSON`。[Apps API — File format](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

适合保存/恢复画布，不适合作为模型向组件下发的日常命令格式。

---

## 3. 命令能否创建公式与图形，且点、线可被学习者拖动

**可以**，前提是对象类型与「固定」属性符合官方对象模型。

### 3.1 创建

- 函数/公式：`f(x) = x^2` 同时出现在代数视图与图形视图。[Input Bar](https://geogebra.github.io/docs/manual/en/Input_Bar/)
- 点：`A=(1,1)` 或 `Point({1, 2})`。[Points and Vectors](https://geogebra.github.io/docs/manual/en/Points_and_Vectors/)；[Point Command](https://geogebra.github.io/docs/manual/en/commands/Point/)
- 线段：`Segment(A, B)` 或 `Segment((1,2),(3,4))`。[Segment Command](https://geogebra.github.io/docs/manual/en/commands/Segment/)；[appletOnLoad 示例](https://geogebra.github.io/docs/reference/en/GeoGebra_App_Parameters/)
- 直线：`Line(A, B)`；也可用参数式 `X = (1, 2) + r (2, 3)`。[Line Command](https://geogebra.github.io/docs/manual/en/commands/Line/)

`evalCommand` 必须用英文命令名。[Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

### 3.2 拖动：自由 vs 依赖 vs 固定

官方对象模型：

- **自由对象**：位置/值不依赖其它对象；由直接输入或点工具等创建；**可以移动，除非被固定**。[Free, Dependent and Auxiliary Objects](https://geogebra.github.io/docs/manual/en/Free_Dependent_and_Auxiliary_Objects/)
- **依赖对象**：由工具/命令从其它对象生成（例如 `Line(A,B)`）。文档在「可移动」条款上只明确写了自由对象。
- **路径上的点**：`Point(<path>)` 得到的点**可沿路径移动**。[Point Command](https://geogebra.github.io/docs/manual/en/commands/Point/)
- **固定对象**（自由或依赖）：不能被移动；还可关掉 Selection Allowed。[Object Properties](https://geogebra.github.io/docs/manual/en/Object_Properties/)；命令 [SetFixed](https://geogebra.github.io/docs/manual/en/commands/SetFixed/)；API `setFixed(objName, fixed, selectionAllowed)`，「fixed objects cannot be changed」。[Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

Move 工具：在图形视图中 **drag and drop Free Objects**；也可用方向键移动选中对象。[Move Tool](https://geogebra.github.io/docs/manual/en/tools/Move/)

因此与本产品需求对齐的做法：

1. 用命令建自由点 `A=(…)`、`B=(…)`（默认可拖）。
2. 用 `Line(A,B)` / `Segment(A,B)` 建线：学习者拖 **A/B**，线作为依赖对象跟着变。不要指望把依赖直线当成自由对象随便平移（官方未把它列为可 drag-and-drop 的自由对象）。
3. 若某点不应被拖：`SetFixed(A, true)` 或 `api.setFixed("A", true, …)`。

API `isIndependent` / `isMoveable` 可查询对象是否独立、是否可移动。[Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

### 3.3 嵌入参数与拖动体验

与拖动相关的参数（默认值来自官方表）：

- `enableLabelDrags`：标签能否拖，默认 `true`
- `enableShiftDragZoom`：平移/缩放画布，默认 `true`
- `capturingThreshold`：点选/拖动灵敏度，默认 `3`（可加大以便触摸）
- `showToolBar`：默认 `false`。未显示工具栏时，仍可通过默认 Move 行为拖自由对象（嵌入后图形视图本身支持拖动；官方 Graphics View：激活 Move 工具后可用鼠标/触控板拖对象）。若产品要明确 Move 模式，可 `showToolBar: true` 或 `setMode`。
- `enableRightClick`：默认 `true`；设为 `false` 会关掉右键菜单/部分快捷键

[GeoGebra App Parameters](https://geogebra.github.io/docs/reference/en/GeoGebra_App_Parameters/)；[Graphics View](https://geogebra.github.io/docs/manual/en/Graphics_View/)

### 3.4 把学习者拖动回传给产品

- `registerObjectUpdateListener("A", fn)` / `registerUpdateListener`：对象更新时回调（拖动过程中点坐标变化会更新）。
- `registerClientListener`：客户端事件含 `dragEnd`、`movingGeos`、`movedGeos`。
- 读坐标：`getXcoord` / `getYcoord`。

[Apps API — Event listeners / Client Events](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

对象脚本还有 **On Drag-end** 触发器。[Scripting](https://geogebra.github.io/docs/manual/en/Scripting/)

---

## 4. 许可证是否允许用在本产品

官方许可证页（2025-11 更新）与 ToS 把「完整 GeoGebra 产品」和「源码」拆开。[License](https://www.geogebra.org/license)；[Terms of Service](https://www.geogebra.org/tos)；仓库 README 指向同一许可证页。[README](https://raw.githubusercontent.com/geogebra/geogebra/master/README.md)

### 4.1 非商业 vs 商业（按「用途」不是按「用户身份」）

- 非商业：主要指学生/教师在家或学校/大学为学业与课堂教学使用，且不追求商业优势或金钱收益。收费学校的教师个人/课堂使用仍可算非商业。
- 商业：出版商、在线学校/大学、非营利组织用 GeoGebra 去获取商业优势、收入或金钱补偿。官方举例包括：用 GeoGebra 制作将出售（含课程/学费）的教材；收费培训/支持；非学术 ebook/教材/期刊中使用；用它协助广告/赞助收入。

**任何商业用途需要专门许可**，联系 `office@geogebra.org` 签订 License and Collaboration Agreement。

本产品（辅助学习英语与数学的应用，画布驱动 GeoGebra）若对学习者收费或作为商业产品运营，落在官方「商业使用」描述内，**不能**只靠非商业协议嵌入官方 Apps。

### 4.2 组件分别怎么授权

官方 FAQ 把产品拆成三块：

1. **Java 源码**：EUPL v1.2。文本：<https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12>。官方写：把源码（或单个库）作为 **EUPL 意义上的衍生作品** 使用、复制、组合、修改、再分发时，可遵守 EUPL，**不受非商业限制**。
2. **安装包与 web 服务**（含 Materials 平台）：GeoGebra 自有条款，**仅非商业**，且须署名。
3. **Language Files**（UI 翻译、文档、UI 图与样式，含 logo/图标/stylesheet）：[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en)，非商业 + 署名。

关键限制原文：源码与 Materials 和/或 Language Files **一起作为 GeoGebra 产品使用**时，仍受该许可证其余条款约束，**必须仅用于非商业**。

CDN 上的 `deployggb.js`、Math Apps Bundle、安装器、材料 iframe，都属于「完整产品 / Materials / web services」路径，不是「孤立源码衍生作品」路径。

完整程序「按开源社区理解大概不算自由软件」，因为安装包、web 服务、语言文件的商业限制覆盖了整体。[License FAQ — Is GeoGebra free and open source software?](https://www.geogebra.org/license)

署名形式：`Made with GeoGebra®`，并链到 <https://www.geogebra.org>。

### 4.3 EUPL copyleft（仅当走「自编译源码」路径时）

EUPL 1.2（欧盟实施决定附件，英文）规定：分发或向公众提供原作或衍生作品时，须按 EUPL（或后续版本，除非标明仅 1.2）授权，且不得附加限制 EUPL 的条款；分发时须提供机器可读源码或指明可自由获取的源码仓库。EUPL 的 “Communication to the public” 覆盖通过网络提供访问。[EUR-Lex: Commission Implementing Decision (EU) 2017/863](https://eur-lex.europa.eu/eli/dec_impl/2017/863/oj)

官方许可证 FAQ 承认：源码无非商业限制，但与 Materials / 语言文件组合成完整产品时整体仍非商业。自编译、去掉官方 Language Files/品牌资源、并履行 EUPL，是否足以把**整个学习产品**做成闭源商业应用，EUPL 对「衍生作品」边界有争议；**官方明确建议商业用途直接谈 Collaboration Agreement**。本笔记不把「自编译即可闭源商用」写成已证实路径。

### 4.4 对本产品的许可含义

| 做法 | 许可状态（按官方文本） |
| --- | --- |
| 嵌入 `www.geogebra.org` 的 Apps / iframe / 材料 | 非商业协议或需商业合同 |
| 自托管官方 Math Apps Bundle | 属于官方提供的 web/安装类材料路径 → 非商业或需商业合同 |
| 本产品收费/订阅 | 官方定义为商业用途 → 需 `office@geogebra.org` 合同 |
| 仅使用 EUPL 源码、不捆绑官方 Materials/Language Files | 可按 EUPL 商业使用，但须 copyleft/源码提供，且不得冒充完整 GeoGebra 产品绕过非商业条款 |

---

## 5. 做不到的边界

1. **依赖对象不能当自由对象拖。** `Line(A,B)` 随 A、B 动；Move 工具文档只保证拖放**自由对象**。[Move Tool](https://geogebra.github.io/docs/manual/en/tools/Move/)；[Free vs Dependent](https://geogebra.github.io/docs/manual/en/Free_Dependent_and_Auxiliary_Objects/)
2. **固定对象不能改/不能拖。** [Object Properties](https://geogebra.github.io/docs/manual/en/Object_Properties/)；[`setFixed`](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
3. **`evalCommand` 必须用英文命令名**；本地化 GUI 不等于 API 命令名。[Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
4. **iframe 材料嵌入没有完整 Apps API / 离线。** [Material Embedding](https://geogebra.github.io/docs/reference/en/Material_Embedding_(Iframe)/)
5. **LaTeX 求值只覆盖常见结构**（如 `x^{2}`、`\frac`、`\sqrt`），不是任意 LaTeX。[Apps API `evalLaTeX`](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
6. **`evalCommandCAS` 返回字符串，不自动等价于图形视图里的可拖对象。** 作图仍应走输入栏/`evalCommand`。
7. **XML 手工改 `.ggb` 易损坏**；官方警告再保存可能丢失非常规修改。[File Format](https://wiki.geogebra.org/en/Reference:File_Format)
8. **Global JavaScript 里在 `ggbOnInit` 之前调用 `ggbApplet` 无效。** [Scripting](https://geogebra.github.io/docs/manual/en/Scripting/)
9. **3D 拖点** 分 x-y 平面与 z 轴两种模式，不是平面里随便拖。[Move Tool — 3D](https://geogebra.github.io/docs/manual/en/tools/Move/)
10. **许可证**：官方 CDN/Bundle/语言包/材料平台默认非商业；商业产品需合同。Language Files 为 NC。完整产品不可当作「无限制开源组件」直接进闭源收费应用。[License](https://www.geogebra.org/license)
11. **没有官方「无 GeoGebra 运行时、只解释命令字符串」的独立微型引擎。** 命令求值发生在 Apps 运行时内部（输入栏 / `evalCommand`）。

---

## 6. 对本产品架构的含义（不实现）

宿主（数学模式画布）应：用 `GGBApplet` 或 `mathApps` 注入 Graphing/Geometry/Classic；把识别出的 **GeoGebra 命令**（英文输入栏语法）交给 `evalCommand` / `evalCommandGetLabels`；用自由点 + 依赖线表达可拖动态图形；用 `registerObjectUpdateListener` 或 `dragEnd` 把学习者操作读回。许可上把「嵌入官方 Apps」当成需要商业合同的依赖，而不是默认免费开源库。

---

## 来源索引

- [GeoGebra Apps Embedding](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_Embedding/)
- [GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
- [GeoGebra App Parameters](https://geogebra.github.io/docs/reference/en/GeoGebra_App_Parameters/)
- [Material Embedding (Iframe)](https://geogebra.github.io/docs/reference/en/Material_Embedding_(Iframe)/)
- [Scripting](https://geogebra.github.io/docs/manual/en/Scripting/)
- [Input Bar](https://geogebra.github.io/docs/manual/en/Input_Bar/)
- [Points and Vectors](https://geogebra.github.io/docs/manual/en/Points_and_Vectors/)
- [Point / Line / Segment / SetFixed commands](https://geogebra.github.io/docs/manual/en/commands/Point/)
- [Free, Dependent and Auxiliary Objects](https://geogebra.github.io/docs/manual/en/Free_Dependent_and_Auxiliary_Objects/)
- [Object Properties](https://geogebra.github.io/docs/manual/en/Object_Properties/)
- [Move Tool](https://geogebra.github.io/docs/manual/en/tools/Move/)
- [File Format](https://wiki.geogebra.org/en/Reference:File_Format) / [XML](https://wiki.geogebra.org/en/Reference:XML)
- [JavaScriptAPI.java](https://github.com/geogebra/geogebra/blob/master/common/src/main/java/org/geogebra/common/plugin/JavaScriptAPI.java)
- [geogebra/geogebra](https://github.com/geogebra/geogebra)
- [License](https://www.geogebra.org/license) / [ToS](https://www.geogebra.org/tos)
- [EUPL 1.2 文本入口](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12) / [EUR-Lex 2017/863](https://eur-lex.europa.eu/eli/dec_impl/2017/863/oj)
- [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en)
