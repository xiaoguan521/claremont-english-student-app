# Supabase 首版数据底座

这份设计对应当前学生端 MVP：老师上传教材、布置朗读任务，学生登录阅读并提交录音，后台异步完成评测并回写结果。

## 1. 核心表

### `profiles`
- 绑定 `auth.users.id`
- 存账号基础资料，后续头像、手机号、昵称都放这里
- 通过 `handle_new_user()` 在用户创建后自动补齐

### `schools`
- 一家培训机构一个 `school`
- 当前按单机构优先设计，但结构上支持后续多校区

### `classes`
- 班级属于 `school`
- 作业和学生都最终挂在班级上下文里

### `memberships`
- 这是权限模型核心
- 不再只靠一个全局 `role_id`
- `school_admin` 可以只挂学校，不挂具体班级
- `teacher` / `student` 通常挂在具体班级

### `materials`
- 存教材元信息
- `pdf_path` 指向 Supabase Storage 的 `materials` 桶
- 第一版只把 PDF 当阅读资源，不在运行时自动抽词

### `assignments`
- 老师发布给某个班级的作业
- 支持 `draft / published / closed / archived`

### `assignment_items`
- 存朗读片段、目标单词、句子、段落
- 这是评测输入的结构化来源
- 比“从 PDF 临时抽取文本”更稳

### `submissions`
- 学生每个作业一条主提交记录
- 当前先限制 `assignment_id + student_id` 唯一，便于 MVP 快速闭环
- 如果后续要支持多次提交，再拆成 attempt 模式

### `submission_assets`
- 提交附件表
- 第一版重点存音频，也为后面波形图、报告截图预留了位置

### `evaluation_jobs`
- 评测任务队列表
- 第三方语音评测不走客户端同步等待，统一异步处理

### `evaluation_results`
- 存结构化分数、鼓励语和原始返回
- 后续即使切换评测供应商，前端也尽量不受影响

## 2. 权限思路

SQL 里已经把首版 RLS helper 和策略一起写了，原则是：

- 学生只能看自己所在学校/班级的数据
- 老师可以看自己所带班级的数据
- 学校管理员可以看本机构范围内的数据
- 提交记录、评测结果按“本人或班级教师”开放

当前这版是为了尽快支撑开发，后续如果要做家长端、跨班教师、总部运营后台，还要再细化。

## 3. 存储桶建议

当前 SQL 先创建两个桶：

- `materials`
  - 用于教材 PDF
  - 建议路径规范：`{school_id}/{material_id}/source.pdf`
- `submission-audio`
  - 用于学生录音
  - 建议路径规范：`{school_id}/{class_id}/{submission_id}/take-1.m4a`

第一轮先把桶建出来即可，`storage.objects` 的细粒度策略可以等文件上传页开始联调时再补。

## 4. 管理员建号约束

当前产品约束已经定了：学生和老师都不允许在 App 里自由注册。

所以这套结构默认配合下面的流程：

1. 关闭 Supabase 的公开注册。
2. 管理员在后台或 Supabase Dashboard 创建账号。
3. 用户创建后自动生成 `profiles`。
4. 后台再补充 `memberships`，把用户挂到学校和班级。
5. 学生端只负责登录，不负责创建账号。

## 5. 下一步怎么接前端

推荐按这个顺序落：

1. 先把 `schools / classes / memberships / assignments / assignment_items` 导入远程库。
2. 登录成功后先查 `profiles` 和 `memberships`。
3. 首页与活动页优先改查 `assignments`。
4. 提交页落 `submissions` 和 `submission_assets`。
5. 结果页再接 `evaluation_jobs` 和 `evaluation_results`。
