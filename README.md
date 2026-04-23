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

如果后续要产出正式签名 Android 包，还需要额外配置签名相关 Secrets。

## 相关仓库

- 学生端：[claremont-english-student-app](https://github.com/xiaoguan521/claremont-english-student-app)
- 教师端：[claremont-english-teacher-app](https://github.com/xiaoguan521/claremont-english-teacher-app)
- 管理端：[claremont-english-management-app](https://github.com/xiaoguan521/claremont-english-management-app)
