# 管理员建号流程

当前项目已经明确采用“管理员创建账号，学生只登录”的模式。前台 Flutter App 不提供自助注册入口。

## 开发阶段的推荐做法

### 方案 A：先用 Supabase Dashboard 手工建号

这条路最快，适合我们现在先把学生端和数据链路跑起来。

操作顺序：

1. 在 Supabase 控制台关闭公开注册。
2. 在 `Authentication > Users` 里创建老师和学生账号。
3. 用户创建后，`profiles` 会被数据库触发器自动补一条记录。
4. 在 SQL Editor 或 Table Editor 里补：
   - `schools`
   - `classes`
   - `memberships`
5. 学生端直接用老师分发的账号登录。

### 方案 B：后续做管理页面时，用服务端接口建号

正式的管理页面不要直接在客户端调用 `auth.signUp()`，而是：

1. 管理员在后台填写学生资料。
2. 后台调用受保护的服务端接口。
3. 服务端用 `service_role` 或 Admin API 创建 Auth 用户。
4. 同步创建或更新 `profiles`。
5. 写入 `memberships`，绑定学校和班级。

这样做的原因是：

- 更符合“管理员建号”的业务约束
- 不把高权限密钥暴露在客户端
- 以后可扩展导入学生、批量开通账号、重置密码

## 当前阶段建议

现阶段先按下面这条最稳：

1. 用 Dashboard 手工建几个测试账号。
2. 先把学生端登录、首页、活动列表、详情页接真数据。
3. 等教师后台开始做时，再补 `admin-create-user` 接口或 Edge Function。

## 推荐的测试账号类型

建议至少准备这三类：

- 一个 `school_admin`
- 一个 `teacher`
- 一个 `student`

并且保证它们都落在同一个 `school` 下，这样首页和列表页联调会更顺。
