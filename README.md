# 克莱蒙英语学生端

面向学生和平板学习场景的 Flutter 应用，基于 `Flutter + Riverpod + GoRouter + Supabase` 构建。

## 当前范围

- 邮箱登录与会话保持
- 学生端门户首页
- 打卡活动列表与任务详情
- 远程 Supabase 数据接入
- 配套数据库迁移、种子数据、Edge Function 与 Storage 策略
- GitHub Actions Android 构建

## 技术栈

- `Flutter`
- `Riverpod`
- `GoRouter`
- `Supabase`

## 本地开发

```bash
flutter pub get
flutter run
```

## 环境变量

复制 `.env.example` 到 `.env`，并填写：

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

如果要显式指定数据模式，也可以配置：

- `APP_DATA_MODE=supabase`

生产包要求：

- Release 构建必须使用 `APP_DATA_MODE=supabase`
- Release 构建必须提供 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`，或对应的 `NEXT_PUBLIC_...` 变量
- 如果内部 QA 需要构建使用 Mock 数据的 release 包，必须显式设置 `ALLOW_RELEASE_MOCK_DATA=true`
- 正式上线包不要设置 `ALLOW_RELEASE_MOCK_DATA=true`

## Supabase 目录

仓库内的 `supabase/` 目录包含：

- 数据库迁移
- 演示种子数据
- Edge Functions
- Storage 对象策略

其中管理员安全建号函数位于：

- `supabase/functions/admin-create-user`

## 教材导入

PU Start 已开始从手写 seed 迁到 manifest 规范：

- 规范文档：`docs/pu-start-textbook-import-spec.md`
- 当前清单：`assets/textbooks/power-up/manifest.json`
- 校验命令：`npm run validate:textbook-manifest`

## GitHub Actions

工作流文件：

- `.github/workflows/flutter-build.yml`

仓库需要配置这些 Secrets：

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `APP_DATA_MODE`

其中 `APP_DATA_MODE` 正式环境应为 `supabase`。CI 默认也会写入 `supabase`，避免 release 包静默回退到 Mock 数据。

如果后续要产出正式签名 Android 包，还需要额外配置签名相关 Secrets。

## 相关仓库

- 学生端：[claremont-english-student-app](https://github.com/xiaoguan521/claremont-english-student-app)
- 教师端：[claremont-english-teacher-app](https://github.com/xiaoguan521/claremont-english-teacher-app)
- 管理端：[claremont-english-management-app](https://github.com/xiaoguan521/claremont-english-management-app)
