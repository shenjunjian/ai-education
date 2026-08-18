# 绘制、手写与拍照如何变成 GeoGebra 命令

调研范围：学习者在画布上绘制几何、手写公式/推导、或拍照识题时，有哪些可追溯到 primary source 的识别路径；这些路径能否稳定产出 GeoGebra 命令或等价几何/代数结构；三条路径的成熟度与输出形态差异。

本稿不实现产品代码，也不评估二手「AI 识题」评测。每条主张后附来源 URL。

## 结论（给后续实现用）

1. **没有一条公开识别栈会直接吐出 GeoGebra 命令字符串。** 官方注入口是 Apps API 的 `evalCommand`（按输入栏英文命令求值）、`evalLaTeX`（有限 LaTeX 子集）、以及 `setXML` / `evalXML` / `setBase64`（整份构造）。见 [GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)。
2. **屏幕几何绘制** 若发生在 GeoGebra 内部，Freehand Shape 会把笔画变成内核对象（圆、线段、多边形、函数图），再可用 `getCommandString` 回读命令。若发生在自有画布，公开路径停在「图元 + 约束」或「图元图」，需一层映射到 `Point` / `Line` / `Segment` / `Circle` / `Polygon`。
3. **手写数学** 的成熟输出是 **Presentation MathML / LaTeX / 厂商树（JIIX）**，不是 GeoGebra 构造。官方竞赛 CROHME 用 InkML + Presentation MathML；胜出系统表达式级正确率可超过 80%，仍不是逐条稳定 100%。
4. **拍照题目** 的成熟输出是 **混排 Markdown + LaTeX（及可选 MathML）**。几何图在公开 OCR API 里大多被标为不支持的 diagram；官方明确支持的几何图仅有三角形顶点/边/标签。
5. **「等价结构」** 对几何是 GeoGebra XML（`geogebra.xml`，XSD `http://geogebra.org/ggb.xsd`）；对代数是 Content MathML / OpenMath 风格的算子树，或 CAS 字符串。Presentation LaTeX/MathML 到这二者都要再走一步，且存在一对多歧义。

## 目标形态：命令 vs 等价结构

### GeoGebra 命令（GGBScript / 输入栏）

GGBScript 就是按顺序执行的输入栏命令。[Scripting 手册](https://geogebra.github.io/docs/manual/en/Scripting/)：执行脚本与把各行输入输入栏效果相同。Apps API 要求 **英文命令名**；自 3.2 起可用 `\n` 一次传入多条。[GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

几何对象的规范命令形态（手册）：

| 意图 | 命令形态（手册） | 来源 |
| --- | --- | --- |
| 点 | `Point({1, 2})` 等 | [Point](https://geogebra.github.io/docs/manual/en/commands/Point/) |
| 直线 | `Line(A, B)`；也可参数式 `X = (1, 2) + r (2, 3)` | [Line](https://geogebra.github.io/docs/manual/en/commands/Line/) |
| 线段 | `Segment(A, B)` | [Segment](https://geogebra.github.io/docs/manual/en/commands/Segment/) |
| 圆 | `Circle(Center, Radius)` / `Circle(Center, Point)` / `Circle(A, B, C)` | [Circle](https://geogebra.github.io/docs/manual/en/commands/Circle/) |
| 多边形 | `Polygon(A, B, C, …)` 或 `Polygon({(0,0),(2,1),(1,3)})` | [Polygon](https://geogebra.github.io/docs/manual/en/commands/Polygon/) |

创建之后可用 `getCommandString(objName)` 取回定义命令，`getValueString` 取值字符串。[GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

`evalLaTeX`（API 表记自 6.0）：把 LaTeX 求值为构造元素；文档只保证常见构造如 `\sqrt{x}`、`\frac{x}{x-1}`。[GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

`evalCommandCAS` 把字符串交给 CAS 并返回字符串，不创建图形对象。[GeoGebra Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

### 等价几何结构：`geogebra.xml`

`.ggb` 是 ZIP；其中 `geogebra.xml` 存整份构造。[File Format](https://geogebra.github.io/docs/reference/en/File_Format/)  
XML 由 schema `http://geogebra.org/ggb.xsd` 定义；可用 `getXML` / `setXML` / `evalXML` / `getBase64` / `setBase64` 读写。[XML](https://geogebra.github.io/docs/reference/en/XML/) · [Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)

这是与命令字符串并列的、官方可加载的几何/代数对象图。手册明确警告：手改 XML 再在 GeoGebra 内保存可能丢失非常规内容。[File Format](https://geogebra.github.io/docs/reference/en/File_Format/)

### 等价代数结构：Content MathML（不是 CROHME 的默认真值）

[MathML 3 Content Markup](https://www.w3.org/TR/MathML3/chapter4.html) 的意图是编码表达式的 **数学含义** 而非排版。Strict Content MathML 与 OpenMath 对象对应。Presentation MathML 只描述版式。[Presentation Markup](https://www.w3.org/TR/MathML3/chapter3.html)

CROHME 官方真值是 **Presentation MathML**（及 Label Graph），组织者写明 **LaTeX 不是规范化真值**。[CROHME 2019 data](https://www.cs.rit.edu/~crohme2019/dataANDtools.html)

因此：手写/拍照识别的「公式」默认是 **外观树**，不是 GeoGebra 内核对象，也不是 Content MathML。

---

## 路径 1：屏幕绘制几何

输入假设：触控/鼠标轨迹（在线笔画），不是照片。笔画交换格式：[W3C InkML](https://www.w3.org/TR/InkML/)（手写、草图、记号语言的公共墨迹交换）。

### 1.1 GeoGebra 自带 Freehand Shape（产品内闭环）

[Freehand Shape Tool](https://geogebra.github.io/docs/manual/en/tools/Freehand_Shape/)（Classic / Graphing / Geometry）：勾函数图，或徒手画圆锥曲线、线段、多边形，会被识别并转为对应精确对象。

对手绘函数：可求值、可放点、可用 `FitSin` 等拟合与 `Integral`；**不能**求解析导数。

这是三条路径里 **唯一官方文档保证「笔画 → GeoGebra 几何对象」** 的路径。对象一旦进入内核，即可 `getCommandString` / `getXML`。它不是独立 REST API：调用方若不用 GeoGebra 画布，就拿不到这条管道。

### 1.2 自有画布上的图元识别（学术栈）

[PaleoSketch (Paulson & Hammond, IUI 2008)](https://dl.acm.org/doi/10.1145/1378773.1378775)：底层图元识别与美化，论文摘要称可识别八类图元及其组合，报告准确率 98.56%，并生成美化后的形状。输出是 **图元类型 + 几何参数**，不是 GeoGebra 命令。

[LADDER (Hammond & Davis)](https://dl.acm.org/doi/10.1145/1185657.1185788)：用预定义形状、约束、编辑与显示方法描述领域草图；形状可分层组合（例如箭头由三条线构成）。输出是 **领域形状 + 约束图**。映射到 GeoGebra 时：图元可对 `Point`/`Line`/`Circle`/`Polygon`；**垂直、平行、等长、点在线上** 等约束对应另一组命令（如 `PerpendicularLine`），识别器若只给图元而不给约束，构造语义会丢。

### 1.3 商业墨迹：MyScript Diagram（形状，不是动态几何）

[MyScript iink：Shapes and connectors](https://developer.myscript.com/docs/interactive-ink/4.4/overview/diagram-features/) 支持圆、椭圆、矩形、平行四边形、梯形、多边形、菱形、各类三角形、弧、箭头等，以及连接线与标签。

[Import/export](https://developer.myscript.com/docs/interactive-ink/4.4/overview/import-and-export-formats/)：Diagram 块可导出 JIIX、SVG、GraphML、PPTX 等，**没有 GeoGebra 命令或 ggb XML**。

这是「稳定的图元图」，要变成 GeoGebra 仍须映射。连接线语义是流程图节点，不是 `Line(A,B)` 那种无限直线或欧氏约束。

### 1.4 墨迹公式 API 对几何图的覆盖（窄）

[Mathpix Convert endpoints](https://mathpix.com/docs/convert/endpoints)：处理几何/化学图时，**几何目前只支持三角形**，表示为 vertices、edges、labels。

[Mathpix `POST /v3/strokes`](https://docs.mathpix.com/reference/post-v3-strokes)：输入为每笔 `x[]`/`y[]`；选项与 `/v3/text` 相同。示例响应是 `latex_styled` / `text`（如 `3 x^{2}`），不是几何构造。

### 1.5 本路径能否稳定产出 GeoGebra 命令

| 子路径 | 原生输出 | 到 GGB 的距离 |
| --- | --- | --- |
| GeoGebra Freehand | 内核对象 | 零：已在构造里；命令可回读 |
| PaleoSketch / LADDER | 图元 ± 约束 | 短：需确定性映射；约束覆盖决定「作图题」成败 |
| MyScript Diagram | JIIX / GraphML / SVG | 中：形状可映射；无动态几何依赖 |
| Mathpix strokes | LaTeX / MMD | 几何几乎不可用（官方仅三角） |

「稳定」在 1.1 上取决于用户是否画得像手册所列类别（函数/圆锥/线段/多边形），手册未给错误率。学术图元识别在受控图元集上报告很高准确率，但不覆盖完整尺规作图语言。

---

## 路径 2：手写数学公式 / 推导

输入：在线笔画（时间戳轨迹）或离线墨迹图像。标准墨迹：[InkML](https://www.w3.org/TR/InkML/)。

### 2.1 竞赛与数据格式（学术真值）

[IAPR-TC11 CROHME](http://www.iapr-tc11.org/mediawiki/index.php/CROHME:_Competition_on_Recognition_of_Online_Handwritten_Mathematical_Expressions)：每条表达式的 InkML 含 (1) traces；(2) 符号切分与类别；(3) **MathML 结构**。系统须输出切分、识别与 MathML。

[CROHME 2019](https://www.cs.rit.edu/~crohme2019/dataANDtools.html)：在线数据为 InkML 与 Label Graph (`.lg`)；结构用 Presentation MathML；**LaTeX 因未规范化而不是官方真值**。离线任务为灰度图。

[ICDAR 2023 CROHME](https://doi.org/10.1007/978-3-031-41679-8_33)（[Zenodo 数据](https://zenodo.org/records/8428035)）：online / offline / bimodal 三任务；同一队伍三任务均胜出，**表达式识别率超过 80%**。评测协议与往届相同，可跨年比较。工具：CROHMElib、LgEval。

「稳定」在竞赛意义上是：在 CROHME 语法与符号集上，最好系统约八成整式完全正确，不是产品级逐条保证。

### 2.2 商业在线识别：MyScript Math

[Recognition / content types](https://developer.myscript.com/docs/interactive-ink/4.4/concepts/content-types/)：Math 可导出 LaTeX、MathML 等。

[REST math example](https://developer.myscript.com/docs/interactive-ink/4.5/web/rest/math-example/)：`application/x-latex` 得到如 `\int ^{b}_{a}f'\left( x\right) dx=f\left( b\right) -f\left( a\right)`；分析结构可用 `application/vnd.myscript.jiix` 或 `application/mathml+xml`。JIIX 是带 `type`/`operands`/`label` 的算子树（例：`power` 节点下底数与指数），并可选求解（`generated` 节点）。

[Import/export](https://developer.myscript.com/docs/interactive-ink/4.4/overview/import-and-export-formats/)：Math 块 → JIIX、LaTeX、MathML。`export.mathml.flavor`：`standard` 或 `ms-office`。

这是手写路径里最接近「等价代数结构」的工业输出（JIIX 树 / MathML），仍不是 GGBScript。

### 2.3 商业在线识别：Mathpix strokes

[Process strokes](https://docs.mathpix.com/reference/post-v3-strokes) · [guide](https://docs.mathpix.com/guides/strokes)：笔画 JSON → `text`（Mathpix Markdown，行间 `\n`，数学在 `\(` `\)` / `\[` `\]`）与单式时的 `latex_styled`，以及 `confidence` / `confidence_rate`。格式选项与 `/v3/text` 相同，故可要 MathML/AsciiMath（经 `data_options`）。

输出仍是排版字符串 + 置信度，不是 GeoGebra 对象。

### 2.4 接到 GeoGebra

公开、无需自写解析器的桥：

1. `evalLaTeX(latex)` — 仅「常见」LaTeX。[Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
2. 把识别结果改写成英文输入栏命令后 `evalCommand` — 例如 `f(x)=x^2`，API 示例为 `evalCommand('f(x)=sin(x)')`。[Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
3. `evalCommandCAS` — 要的是 CAS 文本结果，不是图形构造。

缺口（由上述文档直接推出，无需二手评测）：

- CROHME/MyScript 的矩阵、分段、多行推导远宽于 `evalLaTeX` 所举的 `\sqrt`/`\frac`。
- Presentation MathML / LaTeX 有一对多语义（Content MathML 章所述 H×e vs 化学式「He」）。[MathML 3 §4.1.1](https://www.w3.org/TR/MathML3/chapter4.html)
- 推导过程是多表达式序列 + 自然语言，CROHME 任务是单条表达式，不是证明图。

---

## 路径 3：拍照题目

输入：印刷或手写纸面/屏幕的栅格图。与路径 2 的离线手写任务重叠，但题目通常是 **题干文字 + 公式 + 可选几何/示意图**。

### 3.1 商业图像 OCR：Mathpix `/v3/text`

[POST /v3/text](https://docs.mathpix.com/reference/post-v3-text)：图 → Mathpix Markdown（数学在分隔符内）、可选 HTML、`latex_styled`（**仅当整图可收成单条方程**）、`data`（LaTeX / MathML / AsciiMath 等）。区分 `is_printed` / `is_handwritten`，给 `confidence`。

[Image OCR guide](https://docs.mathpix.com/guides/image-ocr) 示例：手写分段函数 → `latex_styled` 与 `text`。

几何/示意图：

- [Convert endpoints](https://mathpix.com/docs/convert/endpoints)：**几何只支持三角形**（vertices / edges / labels）。
- [v3/text `line_data`](https://docs.mathpix.com/reference/post-v3-text)：`type` 含 `diagram`，subtype 含 `triangle`、`chemistry` 等。Guide 中电路图示例：diagram 行 `error_id: image_not_supported`，`conversion_output: false`，不进入顶层 `text`。[Guide](https://docs.mathpix.com/guides/image-ocr)

因此拍照路径对 **公式+文字** 有官方结构化出口；对 **一般几何附图** 官方行为是检测框而不转构造（三角除外）。

### 3.2 开源：印刷公式图 → LaTeX

[harvardnlp/im2markup](https://github.com/harvardnlp/im2markup)（论文 [arXiv:1609.04938](https://arxiv.org/pdf/1609.04938)）：图像 → 展示性 markup（LaTeX）。数据集是渲染公式图（Im2Latex-100K），与拍照试卷域不同。论文把 CROHME 标为笔画 OCR 域，并与当时系统比较。

[lukas-blecher/LaTeX-OCR (pix2tex)](https://github.com/lukas-blecher/latex-ocr)：ViT 编码器 + Transformer 解码器，公式图 → LaTeX。README 目标即此，不声明几何构造或 GeoGebra。

### 3.3 开源：学术 PDF → 含公式的 Markdown

[facebookresearch/nougat](https://github.com/facebookresearch/nougat)：学术 PDF → 与 Mathpix Markdown 大体兼容的 `.mmd`（含 LaTeX 公式与表）。面向论文页，不是单题照片或尺规图。

### 3.4 接到 GeoGebra

与手写相同：LaTeX → `evalLaTeX` / 改写后 `evalCommand`。额外问题：

- 整页题目的 `text` 含自然语言；`latex_styled` 只在「整图单方程」时出现。[v3/text formats](https://docs.mathpix.com/reference/post-v3-text)
- 几何附图多数不会变成 `Circle`/`Polygon` 命令。
- Nougat/im2markup 不输出 ggb XML。

---

## 三条路径对照

| | 屏幕绘制几何 | 手写公式/推导 | 拍照题目 |
| --- | --- | --- | --- |
| 典型输入 | 在线笔画（InkML 可交换） | 在线笔画或离线公式图 | 印刷/手写页图 |
| 最成熟公开输出 | GeoGebra 对象（仅 Freehand）；否则图元/GraphML | Presentation MathML、LaTeX、JIIX | MMD/LaTeX；可选 MathML；题干文本 |
| 官方竞赛/文档成熟度 | Freehand：产品功能，无公开错误率；PaleoSketch：受控图元高准确率 | CROHME 2023 胜出 >80% 整式；工业 SDK 导出 LaTeX/MathML | 公式 OCR 有完整 REST schema；几何图官方仅三角 |
| 是否直接 GGB 命令 | 仅 GeoGebra 画布内 | 否 | 否 |
| 最短官方桥 | 已在内核 / `getCommandString` | `evalLaTeX`（子集）或改写 `evalCommand` | 抽出公式后同上 |
| 等价结构 | `geogebra.xml`；或点线圆多边形参数 | Content MathML 需另建；JIIX/MathML 是外观或厂商树 | 同左；整题是文档树不是构造 |
| 主要缺口 | 约束与作图步骤；自有画布无官方识别 API | 外观→语义；`evalLaTeX` 子集；多步推导 | 附图；混排；单方程假设 |

**成熟度（仅依据上述 primary sources，不作外部评测）：**

- **手写单条公式（在线）**：格式与评测最标准化（InkML + Presentation MathML + CROHME），工业导出也最完整。
- **拍照公式/混排文字**：REST 与字段（confidence、printed/handwritten、line_data）文档化；几何附图明确不完整。
- **屏幕几何绘制 → 动态几何构造**：只有嵌在 GeoGebra 里的 Freehand 是闭环；外部栈停在静态图元，尺规约束与命令序列无标准识别任务可对标 CROHME。

**输出形态差异（一句话）：** 绘制要的是 **带依赖的几何对象图**；手写要的是 **表达式树**；拍照要的是 **文档（文本块 + 公式块 + 可选图）**。GeoGebra 命令适合前两者的「已消歧义对象」，不适合未切分的整页 OCR 字符串。

## 对「能否稳定产出」的直接回答

- **能稳定产出 GeoGebra 对象（进而命令字符串）**：学习者在 GeoGebra Freehand Shape 里画出手册所列形状；随后 `getCommandString` / `getXML`。[Freehand](https://geogebra.github.io/docs/manual/en/tools/Freehand_Shape/) · [Apps API](https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/)
- **能稳定产出可注入子集**：简单印刷/手写公式 → LaTeX → `evalLaTeX` 所举的 `\sqrt`/`\frac` 一类；或人工/规则改写成 `f(x)=…` 后 `evalCommand`。超出子集则 API 未保证。
- **不能从公开文档推出「稳定」**：完整尺规作图识别、一般几何附图、多步手写推导、任意 CROHME 公式自动变合法 GGBScript。CROHME 最好结果仍有约两成整式错误；Mathpix 对非三角 diagram 返回 `image_not_supported`。

## 来源索引

- GeoGebra Apps API：https://geogebra.github.io/docs/reference/en/GeoGebra_Apps_API/
- GeoGebra Scripting：https://geogebra.github.io/docs/manual/en/Scripting/
- Commands： [Point](https://geogebra.github.io/docs/manual/en/commands/Point/) · [Line](https://geogebra.github.io/docs/manual/en/commands/Line/) · [Segment](https://geogebra.github.io/docs/manual/en/commands/Segment/) · [Circle](https://geogebra.github.io/docs/manual/en/commands/Circle/) · [Polygon](https://geogebra.github.io/docs/manual/en/commands/Polygon/)
- Freehand Shape：https://geogebra.github.io/docs/manual/en/tools/Freehand_Shape/
- File Format / XML：https://geogebra.github.io/docs/reference/en/File_Format/ · https://geogebra.github.io/docs/reference/en/XML/
- W3C InkML：https://www.w3.org/TR/InkML/
- MathML 3 Presentation / Content：https://www.w3.org/TR/MathML3/chapter3.html · https://www.w3.org/TR/MathML3/chapter4.html
- CROHME TC11：http://www.iapr-tc11.org/mediawiki/index.php/CROHME:_Competition_on_Recognition_of_Online_Handwritten_Mathematical_Expressions
- CROHME 2019 data：https://www.cs.rit.edu/~crohme2019/dataANDtools.html
- ICDAR 2023 CROHME：https://doi.org/10.1007/978-3-031-41679-8_33 · https://zenodo.org/records/8428035
- PaleoSketch：https://dl.acm.org/doi/10.1145/1378773.1378775
- LADDER：https://dl.acm.org/doi/10.1145/1185657.1185788
- MyScript content types / math REST / shapes / export：https://developer.myscript.com/docs/interactive-ink/4.4/concepts/content-types/ · https://developer.myscript.com/docs/interactive-ink/4.5/web/rest/math-example/ · https://developer.myscript.com/docs/interactive-ink/4.4/overview/diagram-features/ · https://developer.myscript.com/docs/interactive-ink/4.4/overview/import-and-export-formats/
- Mathpix v3/text · v3/strokes · endpoints · image guide：https://docs.mathpix.com/reference/post-v3-text · https://docs.mathpix.com/reference/post-v3-strokes · https://mathpix.com/docs/convert/endpoints · https://docs.mathpix.com/guides/image-ocr · https://docs.mathpix.com/guides/strokes
- im2markup / 论文：https://github.com/harvardnlp/im2markup · https://arxiv.org/pdf/1609.04938
- pix2tex：https://github.com/lukas-blecher/latex-ocr
- Nougat：https://github.com/facebookresearch/nougat
