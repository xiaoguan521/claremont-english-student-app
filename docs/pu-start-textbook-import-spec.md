# PU Start 教材导入规范

这份规范把 PU Start 从“手写 2 页试点 seed”升级为“清单驱动导入”。后续扩到更多页时，先改 `manifest.json`，再由校验脚本和导入脚本生成数据库数据，避免继续复制粘贴 SQL。

## 1. 当前落地点

- 教材清单：`assets/textbooks/power-up/manifest.json`
- 教材页资源：`assets/textbooks/power-up/`
- 媒体资源：`assets/media/power-up/`
- 校验脚本：`scripts/validate_textbook_manifest.mjs`
- 临时兼容迁移：`supabase/migrations/20260423170000_normalize_textbook_asset_paths.sql`

## 2. 路径规范

所有本地随 App 打包的教材资源必须用 `asset:` 前缀保存到数据库或清单中。

| 资源类型 | 路径格式 | 示例 |
| --- | --- | --- |
| 教材页 PDF | `asset:assets/textbooks/{book}/page-{page}.pdf` | `asset:assets/textbooks/power-up/page-6.pdf` |
| 教材页图片 | `asset:assets/textbooks/{book}/page-{page}.png` | `asset:assets/textbooks/power-up/page-6.png` |
| 示范音频 | `asset:assets/media/{book}/page-{page}-{role}.mp3` | `asset:assets/media/power-up/page-6-ex1.mp3` |
| 教学视频 | `asset:assets/media/{book}/page-{page}-{role}.mp4` | `asset:assets/media/power-up/page-6-demo.mp4` |

禁止继续使用旧路径 `assets/textbook/...`。学生端已做兼容，但导入数据必须统一写入 `assets/textbooks/...`。

## 3. 清单结构

`manifest.json` 是一本教材的唯一导入源，包含 4 层数据。

| 层级 | 说明 | 写入表 |
| --- | --- | --- |
| `textbook` | 教材基本信息、默认尺寸、资源根目录 | `materials` |
| `pages` | 每一页的页码、PDF、页图、页面尺寸 | `material_pages` |
| `pages[].regions` | 页内可点击热区、文本、坐标、排序 | `material_page_regions` |
| `regions[].assets` | 热区绑定的示范音频、教学视频等媒体 | `material_region_assets` |
| `assignments` | 试点作业标题、截止偏移、关联热区 | `assignments` / `assignment_items` |

## 4. 坐标规范

热区坐标统一使用 0 到 1 的相对坐标。

| 字段 | 含义 |
| --- | --- |
| `x` | 热区左边缘相对页面宽度的位置 |
| `y` | 热区上边缘相对页面高度的位置 |
| `width` | 热区宽度相对页面宽度的比例 |
| `height` | 热区高度相对页面高度的比例 |

导入前必须确认：

- `x`、`y` 在 0 到 1 之间。
- `width`、`height` 大于 0 且不超过 1。
- `x + width` 不应超过 1。
- `y + height` 不应超过 1。
- 同一页的 `sortOrder` 按学生练习顺序递增。

## 5. 最小导入流程

1. 把页图、PDF、音频、视频放入约定目录。
2. 在 `assets/textbooks/power-up/manifest.json` 增加页面、热区和媒体绑定。
3. 运行 `npm run validate:textbook-manifest`。
4. 确认 Flutter 资源声明包含对应子目录。
5. 由导入脚本把 manifest 写入 Supabase 表。
6. 在教师端用“教材热区标注”页面抽查热区位置。
7. 在学生端打开对应作业，确认教材页、示范音频、教学视频、录音提交都可用。

## 6. 验收标准

- `npm run validate:textbook-manifest` 通过。
- `flutter test test/power_up_assets_test.dart` 通过。
- `flutter build bundle` 后 `build/flutter_assets/assets/textbooks/power-up/` 内包含所有页图和 PDF。
- 打开 4 月 27 日和 4 月 28 日作业，不再出现 `Unable to load asset`。
- 每个作业项都能定位到一个 `regionKey`，且该热区至少有一个可用示范音频或 TTS 文本。

## 7. 下一步脚本化目标

当前已经有 manifest 与校验脚本。下一步最值得补的是“manifest 到 SQL/upsert”的生成器：

- 输入：`assets/textbooks/power-up/manifest.json`
- 输出：可重复执行的 Supabase upsert SQL
- 主键策略：使用 `schoolCode + materialTitle + pageNumber + regionKey + assignment.key` 做稳定查找
- 行为要求：重复运行不产生重复教材、重复热区或重复作业
- 迁移策略：试点期保留现有 `20260423163000_seed_pu_start_materials.sql`，新页导入逐步切到 manifest 生成
