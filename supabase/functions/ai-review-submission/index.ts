import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type ReviewSubmissionPayload = {
  action: 'review_submission'
  submissionId: string
}

type PreviewTextReviewPayload = {
  action: 'preview_text_review'
  schoolId: string
  transcript: string
  expectedText?: string
  promptText?: string
}

type ProcessQueuePayload = {
  action: 'process_queue'
  batchSize?: number
}

type AiReviewPayload =
  | ReviewSubmissionPayload
  | PreviewTextReviewPayload
  | ProcessQueuePayload

type SchoolAiConfigRecord = {
  school_id: string
  provider_type: string
  provider_label: string
  base_url: string
  model: string
  api_key_ciphertext: string
  enabled: boolean
}

type SubmissionRecord = {
  id: string
  assignment_id: string
  student_id: string
  status: string
}

type AssignmentRecord = {
  id: string
  school_id: string
  title: string
  description: string | null
}

type AssignmentItemRecord = {
  id: string
  title: string | null
  prompt_text: string
  expected_text: string | null
  tts_text: string | null
  sort_order: number
}

type SubmissionAudioAsset = {
  storage_bucket: string
  storage_path: string
  mime_type: string | null
}

type EvaluationJobRecord = {
  id: string
  submission_id: string
  attempt_count: number
  status: string
}

type ReviewNarrative = {
  summaryFeedback: string
  strengths: string[]
  improvementPoints: string[]
  encouragement: string
}

type ReviewOutcome = {
  transcript: string
  summaryFeedback: string
  strengths: string[]
  improvementPoints: string[]
  encouragement: string
  overallScore: number
  pronunciationScore: number
  fluencyScore: number
  completenessScore: number
  taskReviews: TaskReviewOutcome[]
  similarity: {
    charSimilarity: number
    tokenRecall: number
    tokenBalance: number
  }
  transcriptionModel: string
  transcriptionRaw: unknown
  generationRaw: unknown
}

type TaskReviewOutcome = {
  itemId: string
  title: string
  expectedText: string
  overallScore: number
  pronunciationScore: number
  fluencyScore: number
  completenessScore: number
  summaryFeedback: string
  strengths: string[]
  improvementPoints: string[]
  encouragement: string
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

function decodeBase64(value: string) {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0))
}

function encodeBase64(bytes: Uint8Array) {
  let result = ''
  const chunkSize = 0x8000
  for (let index = 0; index < bytes.length; index += chunkSize) {
    const slice = bytes.subarray(index, index + chunkSize)
    result += String.fromCharCode(...slice)
  }
  return btoa(result)
}

async function deriveEncryptionKey(secret: string) {
  const secretBytes = new TextEncoder().encode(secret)
  const digest = await crypto.subtle.digest('SHA-256', secretBytes)

  return crypto.subtle.importKey('raw', digest, { name: 'AES-GCM' }, false, [
    'encrypt',
    'decrypt',
  ])
}

async function decryptApiKey(secret: string, ciphertext: string) {
  const [ivBase64, payloadBase64] = ciphertext.split(':')
  if (!ivBase64 || !payloadBase64) {
    throw new Error('Stored API key ciphertext is invalid.')
  }

  const cryptoKey = await deriveEncryptionKey(secret)
  const decrypted = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: decodeBase64(ivBase64),
    },
    cryptoKey,
    decodeBase64(payloadBase64),
  )

  return new TextDecoder().decode(decrypted)
}

function normalizeBaseUrl(value: string) {
  return value.trim().replace(/\/+$/, '')
}

function normalizeForComparison(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function tokenize(value: string) {
  const normalized = normalizeForComparison(value)
  return normalized === '' ? [] : normalized.split(' ')
}

function clampScore(value: number, minimum = 0, maximum = 100) {
  return Math.min(maximum, Math.max(minimum, Math.round(value)))
}

function levenshteinDistance(source: string, target: string) {
  if (source === target) return 0
  if (source.length === 0) return target.length
  if (target.length === 0) return source.length

  const rows = Array.from({ length: source.length + 1 }, (_, index) => index)
  for (let column = 1; column <= target.length; column += 1) {
    let previous = column - 1
    rows[0] = column
    for (let row = 1; row <= source.length; row += 1) {
      const temp = rows[row]
      rows[row] = Math.min(
        rows[row] + 1,
        rows[row - 1] + 1,
        previous + (source[row - 1] === target[column - 1] ? 0 : 1),
      )
      previous = temp
    }
  }

  return rows[source.length]
}

function buildExpectedText(items: AssignmentItemRecord[]) {
  const parts = items
    .map((item) => {
      const candidates = [item.expected_text, item.tts_text, item.prompt_text]
      for (const candidate of candidates) {
        const trimmed = (candidate ?? '').trim()
        if (trimmed !== '') {
          return trimmed
        }
      }
      return ''
    })
    .filter((part) => part !== '')

  return parts.join(' ')
}

function computeSimilarity(transcript: string, expectedText: string) {
  const normalizedTranscript = normalizeForComparison(transcript)
  const normalizedExpected = normalizeForComparison(expectedText)

  if (!normalizedTranscript || !normalizedExpected) {
    return {
      charSimilarity: 0,
      tokenRecall: 0,
      tokenBalance: 0,
    }
  }

  const maxLength = Math.max(normalizedTranscript.length, normalizedExpected.length)
  const charSimilarity =
    maxLength === 0
      ? 0
      : 1 - levenshteinDistance(normalizedTranscript, normalizedExpected) / maxLength

  const transcriptTokens = tokenize(transcript)
  const expectedTokens = tokenize(expectedText)
  const transcriptCounts = new Map<string, number>()
  for (const token of transcriptTokens) {
    transcriptCounts.set(token, (transcriptCounts.get(token) ?? 0) + 1)
  }

  let overlap = 0
  for (const token of expectedTokens) {
    const count = transcriptCounts.get(token) ?? 0
    if (count > 0) {
      overlap += 1
      transcriptCounts.set(token, count - 1)
    }
  }

  const tokenRecall = expectedTokens.length === 0 ? 0 : overlap / expectedTokens.length
  const transcriptLength = transcriptTokens.length
  const expectedLength = expectedTokens.length
  const tokenBalance =
    transcriptLength === 0 || expectedLength === 0
      ? 0
      : Math.min(transcriptLength, expectedLength) / Math.max(transcriptLength, expectedLength)

  return {
    charSimilarity: Math.max(0, Math.min(1, charSimilarity)),
    tokenRecall: Math.max(0, Math.min(1, tokenRecall)),
    tokenBalance: Math.max(0, Math.min(1, tokenBalance)),
  }
}

function buildScores(transcript: string, expectedText: string) {
  const similarity = computeSimilarity(transcript, expectedText)
  const blended =
    similarity.charSimilarity * 0.52 +
    similarity.tokenRecall * 0.33 +
    similarity.tokenBalance * 0.15

  const overallScore = clampScore(blended * 100, 60, 98)
  const completenessScore = clampScore(
    similarity.tokenRecall * 100 * 0.82 + overallScore * 0.18,
    60,
    99,
  )
  const fluencyScore = clampScore(
    overallScore + (similarity.tokenBalance >= 0.92 ? 3 : -5),
    60,
    99,
  )
  const pronunciationScore = clampScore(
    overallScore + (similarity.charSimilarity >= 0.92 ? 2 : -3),
    60,
    99,
  )

  return {
    similarity,
    overallScore,
    completenessScore,
    fluencyScore,
    pronunciationScore,
  }
}

function fallbackTaskNarrative(expectedText: string, transcript: string, overallScore: number) {
  const normalizedExpected = normalizeForComparison(expectedText)
  const normalizedTranscript = normalizeForComparison(transcript)
  const expectedWords = tokenize(expectedText)
  const transcriptWords = tokenize(transcript)
  const matched = normalizedExpected !== '' && normalizedTranscript.includes(normalizedExpected)

  if (matched || overallScore >= 92) {
    return {
      summaryFeedback: '这一句读得很接近标准，继续保持现在的节奏。',
      strengths: ['句子主要内容读出来了', '声音比较自然'],
      improvementPoints: ['句尾可以再收紧一点'],
      encouragement: '这一句读得不错，再自信一点会更棒。',
    }
  }

  if (overallScore >= 75) {
    return {
      summaryFeedback: '这一句大部分已经读对了，再把重点单词读完整一点会更好。',
      strengths: ['愿意完整开口跟读', '语速比较稳定'],
      improvementPoints: ['再对照示范，把整句读完整', '注意停顿和连读'],
      encouragement: '你已经读对了大部分内容，再练一遍就会更稳。',
    }
  }

  return {
    summaryFeedback:
      transcriptWords.length >= expectedWords.length
        ? '这一句已经勇敢读出来了，接下来重点把发音读得更准确。'
        : '这一句先把内容完整读出来，再跟着示范把语音读稳。',
    strengths: ['愿意尝试开口朗读'],
    improvementPoints: ['先把整句内容读完整', '跟着示范多听一遍再读'],
    encouragement: '别着急，这一句再跟着示范练一遍就会越来越顺。',
  }
}

function extractMessageText(content: unknown): string {
  if (typeof content === 'string') {
    return content.trim()
  }

  if (Array.isArray(content)) {
    return content
      .map((item) => {
        if (typeof item === 'string') return item
        if (item && typeof item === 'object' && 'text' in item) {
          return typeof item.text === 'string' ? item.text : ''
        }
        return ''
      })
      .join('\n')
      .trim()
  }

  return ''
}

function extractReasoningText(value: unknown): string {
  if (typeof value === 'string') {
    return value.trim()
  }

  if (Array.isArray(value)) {
    return value
      .map((item) => {
        if (typeof item === 'string') return item
        if (item && typeof item === 'object' && 'text' in item) {
          return typeof item.text === 'string' ? item.text : ''
        }
        return ''
      })
      .join('\n')
      .trim()
  }

  return ''
}

function parseJsonFromText(content: string) {
  const trimmed = content.trim()
  if (!trimmed) {
    throw new Error('AI response content is empty.')
  }

  try {
    return JSON.parse(trimmed) as Record<string, unknown>
  } catch {
    const start = trimmed.indexOf('{')
    const end = trimmed.lastIndexOf('}')
    if (start >= 0 && end > start) {
      return JSON.parse(trimmed.slice(start, end + 1)) as Record<string, unknown>
    }
    throw new Error('AI response is not valid JSON.')
  }
}

function ensureStringArray(value: unknown, fallback: string[]) {
  if (!Array.isArray(value)) {
    return fallback
  }

  const next = value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter((item) => item !== '')

  return next.length > 0 ? next.slice(0, 3) : fallback
}

function fallbackNarrative(expectedText: string, transcript: string, overallScore: number): ReviewNarrative {
  const expectedWords = tokenize(expectedText).length
  const actualWords = tokenize(transcript).length
  const lengthHint =
    actualWords >= expectedWords
      ? '整体内容基本覆盖到了老师要求的句子。'
      : '有一部分内容没有完整说出来，建议再跟着示范多读一遍。'

  return {
    summaryFeedback: `本次 AI 初评得分约 ${overallScore} 分。${lengthHint}`,
    strengths: ['敢于完整开口朗读', '能根据教材内容完成本次提交'],
    improvementPoints: ['对照示范音频，把句子读得更完整一点', '注意停顿和句尾收音'],
    encouragement: '已经很接近了，再跟着示范音频多练一遍会更稳定。',
  }
}

async function fetchSchoolAiConfig(
  adminClient: ReturnType<typeof createClient>,
  schoolId: string,
) {
  const { data, error } = await adminClient
    .from('school_ai_configs')
    .select(
      'school_id, provider_type, provider_label, base_url, model, api_key_ciphertext, enabled',
    )
    .eq('school_id', schoolId)
    .maybeSingle()

  if (error) {
    throw new Error(error.message)
  }

  return (data as SchoolAiConfigRecord | null) ?? null
}

async function transcribeAudio(options: {
  baseUrl: string
  apiKey: string
  audioBlob: Blob
  fileName: string
  mimeType: string
}) {
  const transcriptionModels = (Deno.env.get('AI_TRANSCRIPTION_MODELS') ??
    'gpt-4o-mini-transcribe,gpt-4o-transcribe,whisper-1')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item !== '')

  const errors: string[] = []
  const authHeaders = options.apiKey
    ? { Authorization: `Bearer ${options.apiKey}` }
    : {}

  for (const model of transcriptionModels) {
    const formData = new FormData()
    formData.append('model', model)
    formData.append('file', new File([options.audioBlob], options.fileName, { type: options.mimeType }))

    const response = await fetch(`${options.baseUrl}/audio/transcriptions`, {
      method: 'POST',
      headers: authHeaders,
      body: formData,
      signal: AbortSignal.timeout(45000),
    })

    if (!response.ok) {
      errors.push(`${model}: ${response.status} ${await response.text()}`)
      continue
    }

    const data = (await response.json()) as Record<string, unknown>
    const transcript =
      typeof data.text === 'string'
        ? data.text.trim()
        : typeof data.transcript === 'string'
          ? data.transcript.trim()
          : ''

    if (!transcript) {
      errors.push(`${model}: empty transcript`)
      continue
    }

    return {
      transcript,
      transcriptionModel: model,
      transcriptionRaw: data,
    }
  }

  const audioChatModels = (Deno.env.get('AI_AUDIO_CHAT_TRANSCRIPTION_MODELS') ??
    'mimo-v2-omni')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item !== '')

  if (audioChatModels.length > 0) {
    const audioBuffer = await options.audioBlob.arrayBuffer()
    const audioBase64 = encodeBase64(new Uint8Array(audioBuffer))
    const format = options.mimeType.includes('wav')
      ? 'wav'
      : options.mimeType.includes('aac')
        ? 'aac'
        : options.mimeType.includes('webm')
          ? 'webm'
          : options.mimeType.includes('ogg')
            ? 'ogg'
            : options.mimeType.includes('mp4') || options.mimeType.includes('m4a')
              ? 'mp4'
              : 'mp3'

    for (const model of audioChatModels) {
      const response = await fetch(`${options.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'user',
              content: [
                {
                  type: 'text',
                  text: '请把这段英文音频转写成纯文本，只返回转写内容，不要解释。',
                },
                {
                  type: 'input_audio',
                  input_audio: {
                    data: audioBase64,
                    format,
                  },
                },
              ],
            },
          ],
        }),
        signal: AbortSignal.timeout(45000),
      })

      if (!response.ok) {
        errors.push(`${model}: ${response.status} ${await response.text()}`)
        continue
      }

      const data = (await response.json()) as Record<string, unknown>
      const choices = Array.isArray(data.choices) ? data.choices : []
      const firstChoice = choices[0] as Record<string, unknown> | undefined
      const message = (firstChoice?.message as Record<string, unknown> | undefined) ?? {}
      const transcript =
        extractMessageText(message.content) ||
        extractReasoningText(message.reasoning_content)

      if (!transcript) {
        errors.push(`${model}: empty transcript`)
        continue
      }

      return {
        transcript,
        transcriptionModel: `${model}:audio-chat`,
        transcriptionRaw: data,
      }
    }
  }

  throw new Error(`Audio transcription failed. ${errors.join(' | ')}`)
}

async function generateReviewNarrative(options: {
  baseUrl: string
  apiKey: string
  model: string
  providerLabel: string
  assignmentTitle: string
  assignmentDescription: string | null
  promptText: string
  expectedText: string
  transcript: string
  overallScore: number
  completenessScore: number
  fluencyScore: number
  pronunciationScore: number
}) {
  const response = await fetch(`${options.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(options.apiKey
        ? {
            Authorization: `Bearer ${options.apiKey}`,
          }
        : {}),
    },
    body: JSON.stringify({
      model: options.model,
      messages: [
        {
          role: 'system',
          content:
            'You are an English homework review assistant for K12 students. Return JSON only with keys: summaryFeedback, strengths, improvementPoints, encouragement. strengths and improvementPoints must be arrays of 1-3 short Chinese strings. summaryFeedback and encouragement must be concise Chinese sentences.',
        },
        {
          role: 'user',
          content: [
            `provider: ${options.providerLabel}`,
            `assignment title: ${options.assignmentTitle}`,
            `assignment description: ${options.assignmentDescription ?? ''}`,
            `prompt text: ${options.promptText}`,
            `expected text: ${options.expectedText}`,
            `student transcript: ${options.transcript}`,
            `heuristic overall score: ${options.overallScore}`,
            `heuristic pronunciation score: ${options.pronunciationScore}`,
            `heuristic fluency score: ${options.fluencyScore}`,
            `heuristic completeness score: ${options.completenessScore}`,
            'Write feedback for a primary school student. Keep the tone warm, encouraging, and concrete.',
          ].join('\n'),
        },
      ],
    }),
    signal: AbortSignal.timeout(45000),
  })

  if (!response.ok) {
    throw new Error(`Review generation failed. ${response.status} ${await response.text()}`)
  }

  const data = (await response.json()) as Record<string, unknown>
  const choices = Array.isArray(data.choices) ? data.choices : []
  const firstChoice = choices[0] as Record<string, unknown> | undefined
  const message = (firstChoice?.message as Record<string, unknown> | undefined) ?? {}
  const content =
    extractMessageText(message.content) ||
    extractReasoningText(message.reasoning_content)
  const parsed = parseJsonFromText(content)

  return {
    narrative: {
      summaryFeedback:
        typeof parsed.summaryFeedback === 'string'
          ? parsed.summaryFeedback.trim()
          : fallbackNarrative(options.expectedText, options.transcript, options.overallScore)
              .summaryFeedback,
      strengths: ensureStringArray(parsed.strengths, fallbackNarrative(
        options.expectedText,
        options.transcript,
        options.overallScore,
      ).strengths),
      improvementPoints: ensureStringArray(parsed.improvementPoints, fallbackNarrative(
        options.expectedText,
        options.transcript,
        options.overallScore,
      ).improvementPoints),
      encouragement:
        typeof parsed.encouragement === 'string'
          ? parsed.encouragement.trim()
          : fallbackNarrative(options.expectedText, options.transcript, options.overallScore)
              .encouragement,
    } satisfies ReviewNarrative,
    generationRaw: data,
  }
}

async function buildReviewOutcome(options: {
  config: SchoolAiConfigRecord
  apiKey: string
  assignment: AssignmentRecord
  items: AssignmentItemRecord[]
  audioBlob: Blob
  audioFileName: string
  audioMimeType: string
}) {
  const promptText = options.items
    .map((item) =>
      [item.title, item.prompt_text]
        .map((part) => (part ?? '').trim())
        .filter((part) => part !== '')
        .join('：'),
    )
    .join('\n')
  const expectedText = buildExpectedText(options.items)

  const { transcript, transcriptionModel, transcriptionRaw } = await transcribeAudio({
    baseUrl: normalizeBaseUrl(options.config.base_url),
    apiKey: options.apiKey,
    audioBlob: options.audioBlob,
    fileName: options.audioFileName,
    mimeType: options.audioMimeType,
  })

  if (!transcript.trim()) {
    throw new Error('Audio transcription returned empty content.')
  }

  const scores = buildScores(transcript, expectedText)
  const { narrative, generationRaw } = await generateReviewNarrative({
    baseUrl: normalizeBaseUrl(options.config.base_url),
    apiKey: options.apiKey,
    model: options.config.model,
    providerLabel: options.config.provider_label,
    assignmentTitle: options.assignment.title,
    assignmentDescription: options.assignment.description,
    promptText,
    expectedText,
    transcript,
    overallScore: scores.overallScore,
    completenessScore: scores.completenessScore,
    fluencyScore: scores.fluencyScore,
    pronunciationScore: scores.pronunciationScore,
  })

  const taskReviews = options.items.map((item) => {
    const expectedText =
      (item.expected_text ?? '').trim() ||
      (item.tts_text ?? '').trim() ||
      item.prompt_text.trim()
    const itemScores = buildScores(transcript, expectedText)
    const taskNarrative = fallbackTaskNarrative(
      expectedText,
      transcript,
      itemScores.overallScore,
    )

    return {
      itemId: item.id,
      title: item.title?.trim() || item.prompt_text.trim(),
      expectedText,
      overallScore: itemScores.overallScore,
      pronunciationScore: itemScores.pronunciationScore,
      fluencyScore: itemScores.fluencyScore,
      completenessScore: itemScores.completenessScore,
      summaryFeedback: taskNarrative.summaryFeedback,
      strengths: taskNarrative.strengths,
      improvementPoints: taskNarrative.improvementPoints,
      encouragement: taskNarrative.encouragement,
    } satisfies TaskReviewOutcome
  })

  return {
    transcript,
    summaryFeedback: narrative.summaryFeedback,
    strengths: narrative.strengths,
    improvementPoints: narrative.improvementPoints,
    encouragement: narrative.encouragement,
    overallScore: scores.overallScore,
    pronunciationScore: scores.pronunciationScore,
    fluencyScore: scores.fluencyScore,
    completenessScore: scores.completenessScore,
    taskReviews,
    similarity: scores.similarity,
    transcriptionModel,
    transcriptionRaw,
    generationRaw,
  } satisfies ReviewOutcome
}

async function markJobFailed(options: {
  adminClient: ReturnType<typeof createClient>
  jobId: string
  submissionId: string
  error: string
}) {
  await options.adminClient
    .from('evaluation_jobs')
    .update({
      status: 'failed',
      last_error: options.error,
      updated_at: new Date().toISOString(),
    })
    .eq('id', options.jobId)

  await options.adminClient
    .from('submissions')
    .update({
      status: 'failed',
      updated_at: new Date().toISOString(),
    })
    .eq('id', options.submissionId)
}

async function queueSubmissionReview(options: {
  adminClient: ReturnType<typeof createClient>
  schoolConfig: SchoolAiConfigRecord
  submission: SubmissionRecord
  assignment: AssignmentRecord
  existingJob: EvaluationJobRecord | null
  requestedBy: string
}) {
  const existingStatus = options.existingJob?.status ?? null
  if (existingStatus === 'processing') {
    return {
      queued: false,
      status: 'processing',
      message: 'AI 初评已经在处理中，请稍后刷新查看结果。',
      job: options.existingJob,
    } as const
  }

  if (existingStatus === 'pending' || existingStatus === 'retrying') {
    return {
      queued: false,
      status: 'queued',
      message: 'AI 初评已经在队列中了，请稍后刷新查看结果。',
      job: options.existingJob,
    } as const
  }

  const now = new Date().toISOString()
  const provider = `ai-review:${options.schoolConfig.provider_type}:${options.schoolConfig.model}`
  const nextStatus = existingStatus === 'failed' ? 'retrying' : 'pending'

  const { data: queuedJob, error: queueError } = await options.adminClient
    .from('evaluation_jobs')
    .upsert(
      {
        submission_id: options.submission.id,
        provider,
        status: nextStatus,
        last_error: null,
        request_payload: {
          schoolId: options.assignment.school_id,
          assignmentId: options.assignment.id,
          requestedBy: options.requestedBy,
          model: options.schoolConfig.model,
          baseUrl: options.schoolConfig.base_url,
          dispatchMode: 'background',
          queuedAt: now,
        },
        requested_at: options.existingJob ? undefined : now,
        started_at: null,
        completed_at: null,
        updated_at: now,
      },
      { onConflict: 'submission_id' },
    )
    .select('id, submission_id, attempt_count, status')
    .single()

  if (queueError || !queuedJob) {
    throw new Error(queueError?.message ?? 'Unable to queue evaluation job.')
  }

  await options.adminClient
    .from('submissions')
    .update({
      status: 'queued',
      updated_at: now,
    })
    .eq('id', options.submission.id)

  return {
    queued: true,
    status: 'queued',
    message:
      existingStatus === 'failed'
        ? 'AI 初评已重新入队，系统会在后台自动重试。'
        : '录音已经收到，AI 初评已进入后台队列。',
    job: queuedJob as EvaluationJobRecord,
  } as const
}

async function processSubmissionReview(options: {
  adminClient: ReturnType<typeof createClient>
  schoolConfig: SchoolAiConfigRecord
  encryptionSecret: string
  submission: SubmissionRecord
  assignment: AssignmentRecord
  items: AssignmentItemRecord[]
  audioAsset: SubmissionAudioAsset
  existingJob: EvaluationJobRecord | null
  requestedBy: string
}) {
  const now = new Date().toISOString()
  const attemptCount = (options.existingJob?.attempt_count ?? 0) + 1
  const provider = `ai-review:${options.schoolConfig.provider_type}:${options.schoolConfig.model}`

  const { data: job, error: jobError } = await options.adminClient
    .from('evaluation_jobs')
    .upsert(
      {
        submission_id: options.submission.id,
        provider,
        status: 'processing',
        attempt_count: attemptCount,
        last_error: null,
        request_payload: {
          schoolId: options.assignment.school_id,
          assignmentId: options.assignment.id,
          requestedBy: options.requestedBy,
          model: options.schoolConfig.model,
          baseUrl: options.schoolConfig.base_url,
        },
        requested_at: options.existingJob ? undefined : now,
        started_at: now,
        completed_at: null,
        updated_at: now,
      },
      { onConflict: 'submission_id' },
    )
    .select('id, submission_id, attempt_count, status')
    .single()

  if (jobError || !job) {
    throw new Error(jobError?.message ?? 'Unable to create evaluation job.')
  }

  await options.adminClient
    .from('submissions')
    .update({
      status: 'processing',
      updated_at: now,
    })
    .eq('id', options.submission.id)

  try {
    const apiKey = await decryptApiKey(
      options.encryptionSecret,
      options.schoolConfig.api_key_ciphertext,
    )
    const { data: audioBlob, error: audioError } = await options.adminClient.storage
      .from(options.audioAsset.storage_bucket)
      .download(options.audioAsset.storage_path)

    if (audioError || !audioBlob) {
      throw new Error(audioError?.message ?? 'Unable to download submission audio.')
    }

    const reviewOutcome = await buildReviewOutcome({
      config: options.schoolConfig,
      apiKey,
      assignment: options.assignment,
      items: options.items,
      audioBlob,
      audioFileName: options.audioAsset.storage_path.split('/').pop() ?? 'submission-audio.m4a',
      audioMimeType: options.audioAsset.mime_type ?? 'audio/mp4',
    })

    const completedAt = new Date().toISOString()

    const { error: resultError } = await options.adminClient
      .from('evaluation_results')
      .upsert(
        {
          submission_id: options.submission.id,
          job_id: job.id,
          provider,
          overall_score: reviewOutcome.overallScore,
          pronunciation_score: reviewOutcome.pronunciationScore,
          fluency_score: reviewOutcome.fluencyScore,
          completeness_score: reviewOutcome.completenessScore,
          strengths: reviewOutcome.strengths,
          improvement_points: reviewOutcome.improvementPoints,
          encouragement: reviewOutcome.encouragement,
          raw_result: {
            transcript: reviewOutcome.transcript,
            similarity: reviewOutcome.similarity,
            transcriptionModel: reviewOutcome.transcriptionModel,
            taskReviews: reviewOutcome.taskReviews,
            transcriptionRaw: reviewOutcome.transcriptionRaw,
            generationRaw: reviewOutcome.generationRaw,
          },
          evaluated_at: completedAt,
          updated_at: completedAt,
        },
        { onConflict: 'submission_id' },
      )

    if (resultError) {
      throw new Error(resultError.message)
    }

    await options.adminClient
      .from('submissions')
      .update({
        status: 'completed',
        latest_score: reviewOutcome.overallScore,
        latest_feedback: reviewOutcome.summaryFeedback,
        updated_at: completedAt,
      })
      .eq('id', options.submission.id)

    await options.adminClient
      .from('evaluation_jobs')
      .update({
        status: 'completed',
        completed_at: completedAt,
        updated_at: completedAt,
        request_payload: {
          schoolId: options.assignment.school_id,
          assignmentId: options.assignment.id,
          requestedBy: options.requestedBy,
          model: options.schoolConfig.model,
          baseUrl: options.schoolConfig.base_url,
          transcriptModel: reviewOutcome.transcriptionModel,
        },
      })
      .eq('id', job.id)

    return {
      status: 'completed',
      message: 'AI 初评已经完成，学生端刷新后就能看到。',
      overallScore: reviewOutcome.overallScore,
      transcript: reviewOutcome.transcript,
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'AI review failed.'
    await markJobFailed({
      adminClient: options.adminClient,
      jobId: job.id,
      submissionId: options.submission.id,
      error: message,
    })
    return {
      status: 'failed',
      message: `AI 初评失败：${message}`,
    }
  }
}

async function fetchSubmissionReviewContext(options: {
  adminClient: ReturnType<typeof createClient>
  encryptionSecret: string
  submission: SubmissionRecord
  requestedBy: string
}) {
  const { data: assignment, error: assignmentError } = await options.adminClient
    .from('assignments')
    .select('id, school_id, title, description')
    .eq('id', options.submission.assignment_id)
    .single()

  if (assignmentError || !assignment) {
    throw new Error(assignmentError?.message ?? 'Assignment not found.')
  }

  const schoolConfig = await fetchSchoolAiConfig(
    options.adminClient,
    (assignment as AssignmentRecord).school_id,
  )

  if (!schoolConfig || !schoolConfig.enabled) {
    throw new Error('School AI config is missing or disabled.')
  }

  const { data: existingResult, error: existingResultError } = await options.adminClient
    .from('evaluation_results')
    .select('provider')
    .eq('submission_id', options.submission.id)
    .maybeSingle()

  if (existingResultError) {
    throw new Error(existingResultError.message)
  }

  const { data: items, error: itemsError } = await options.adminClient
    .from('assignment_items')
    .select('id, title, prompt_text, expected_text, tts_text, sort_order')
    .eq('assignment_id', options.submission.assignment_id)
    .order('sort_order', { ascending: true })

  if (itemsError) {
    throw new Error(itemsError.message)
  }

  const { data: audioAsset, error: audioAssetError } = await options.adminClient
    .from('submission_assets')
    .select('storage_bucket, storage_path, mime_type')
    .eq('submission_id', options.submission.id)
    .eq('asset_type', 'audio')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  if (audioAssetError) {
    throw new Error(audioAssetError.message)
  }

  if (!audioAsset) {
    throw new Error('This submission has no audio asset yet.')
  }

  const { data: existingJob, error: existingJobError } = await options.adminClient
    .from('evaluation_jobs')
    .select('id, submission_id, attempt_count, status')
    .eq('submission_id', options.submission.id)
    .maybeSingle()

  if (existingJobError) {
    throw new Error(existingJobError.message)
  }

  return {
    assignment: assignment as AssignmentRecord,
    schoolConfig,
    existingResult:
      existingResult && typeof existingResult.provider === 'string'
        ? existingResult.provider
        : null,
    items: (items ?? []) as AssignmentItemRecord[],
    audioAsset: audioAsset as SubmissionAudioAsset,
    existingJob: (existingJob as EvaluationJobRecord | null) ?? null,
    requestedBy: options.requestedBy,
  }
}

async function processQueuedReviewBatch(options: {
  adminClient: ReturnType<typeof createClient>
  encryptionSecret: string
  batchSize: number
}) {
  const { data: queuedJobs, error: jobsError } = await options.adminClient
    .from('evaluation_jobs')
    .select('id, submission_id, attempt_count, status, request_payload, requested_at')
    .in('status', ['pending', 'retrying'])
    .order('requested_at', { ascending: true })
    .limit(options.batchSize)

  if (jobsError) {
    throw new Error(jobsError.message)
  }

  const jobs = (queuedJobs ?? []) as Array<
    EvaluationJobRecord & { request_payload?: Record<string, unknown> | null }
  >

  if (jobs.length === 0) {
    return {
      status: 'idle',
      processed: 0,
      completed: 0,
      failed: 0,
      skipped: 0,
      message: '当前没有待消费的 AI 评审任务。',
    }
  }

  let completed = 0
  let failed = 0
  let skipped = 0

  for (const job of jobs) {
    const { data: submission, error: submissionError } = await options.adminClient
      .from('submissions')
      .select('id, assignment_id, student_id, status')
      .eq('id', job.submission_id)
      .maybeSingle()

    if (submissionError || !submission) {
      failed += 1
      if (job.id) {
        await markJobFailed({
          adminClient: options.adminClient,
          jobId: job.id,
          submissionId: job.submission_id,
          error: submissionError?.message ?? 'Submission not found.',
        })
      }
      continue
    }

    try {
      const context = await fetchSubmissionReviewContext({
        adminClient: options.adminClient,
        encryptionSecret: options.encryptionSecret,
        submission: submission as SubmissionRecord,
        requestedBy:
          (job.request_payload?.requestedBy as string | undefined) ?? 'queue-worker',
      })

      if (context.existingResult === 'teacher-review') {
        await options.adminClient
          .from('evaluation_jobs')
          .update({
            status: 'completed',
            completed_at: new Date().toISOString(),
            last_error: null,
            updated_at: new Date().toISOString(),
          })
          .eq('id', job.id)
        skipped += 1
        continue
      }

      const result = await processSubmissionReview({
        adminClient: options.adminClient,
        schoolConfig: context.schoolConfig,
        encryptionSecret: options.encryptionSecret,
        submission: submission as SubmissionRecord,
        assignment: context.assignment,
        items: context.items,
        audioAsset: context.audioAsset,
        existingJob: context.existingJob ?? job,
        requestedBy: context.requestedBy,
      })

      if (result.status === 'completed') {
        completed += 1
      } else {
        failed += 1
      }
    } catch (error) {
      failed += 1
      if (job.id) {
        await markJobFailed({
          adminClient: options.adminClient,
          jobId: job.id,
          submissionId: job.submission_id,
          error: error instanceof Error ? error.message : 'Queue worker failed.',
        })
      }
    }
  }

  return {
    status: 'completed',
    processed: jobs.length,
    completed,
    failed,
    skipped,
    message: `本轮消费了 ${jobs.length} 条评审任务。`,
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed.' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const encryptionSecret = Deno.env.get('AI_CONFIG_ENCRYPTION_KEY') ?? ''
  const queueSecret = Deno.env.get('AI_REVIEW_QUEUE_SECRET') ?? ''
  const authHeader = req.headers.get('Authorization')

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return json({ error: 'Supabase function secrets are not configured.' }, 500)
  }

  if (!encryptionSecret.trim()) {
    return json({ error: 'AI encryption secret is not configured.' }, 500)
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  })

  try {
    const payload = (await req.json()) as AiReviewPayload

    if (payload.action === 'process_queue') {
      const requestQueueSecret = req.headers.get('x-queue-secret') ?? ''
      if (!queueSecret.trim() || requestQueueSecret !== queueSecret) {
        return json({ error: 'Invalid queue worker secret.' }, 401)
      }

      const batchSize = Math.min(
        10,
        Math.max(
          1,
          typeof payload.batchSize === 'number' && Number.isFinite(payload.batchSize)
            ? Math.round(payload.batchSize)
            : 3,
        ),
      )

      const result = await processQueuedReviewBatch({
        adminClient,
        encryptionSecret,
        batchSize,
      })

      return json(result)
    }

    if (!authHeader) {
      return json({ error: 'Missing authorization header.' }, 401)
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    })

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser()

    if (userError || !user) {
      return json({ error: 'Unable to validate current user.' }, 401)
    }

    if (payload.action === 'preview_text_review') {
      if (!payload.schoolId?.trim() || !payload.transcript?.trim()) {
        return json({ error: 'schoolId and transcript are required.' }, 400)
      }

      const { data: operatorMembership, error: membershipError } = await userClient
        .from('memberships')
        .select('id')
        .eq('user_id', user.id)
        .eq('school_id', payload.schoolId)
        .eq('role', 'school_admin')
        .eq('status', 'active')
        .maybeSingle()

      if (membershipError || !operatorMembership) {
        return json({ error: 'Current user is not allowed to preview this school config.' }, 403)
      }

      const config = await fetchSchoolAiConfig(adminClient, payload.schoolId)
      if (!config || !config.enabled) {
        return json({ error: 'School AI config is missing or disabled.' }, 400)
      }

      const apiKey = await decryptApiKey(encryptionSecret, config.api_key_ciphertext)
      const expectedText = payload.expectedText?.trim() || payload.transcript.trim()
      const scores = buildScores(payload.transcript, expectedText)
      const { narrative } = await generateReviewNarrative({
        baseUrl: normalizeBaseUrl(config.base_url),
        apiKey,
        model: config.model,
        providerLabel: config.provider_label,
        assignmentTitle: 'Preview',
        assignmentDescription: null,
        promptText: payload.promptText?.trim() || 'Preview text review',
        expectedText,
        transcript: payload.transcript.trim(),
        overallScore: scores.overallScore,
        completenessScore: scores.completenessScore,
        fluencyScore: scores.fluencyScore,
        pronunciationScore: scores.pronunciationScore,
      })

      return json({
        status: 'completed',
        preview: {
          overallScore: scores.overallScore,
          pronunciationScore: scores.pronunciationScore,
          fluencyScore: scores.fluencyScore,
          completenessScore: scores.completenessScore,
          summaryFeedback: narrative.summaryFeedback,
          strengths: narrative.strengths,
          improvementPoints: narrative.improvementPoints,
          encouragement: narrative.encouragement,
        },
      })
    }

    if (!payload.submissionId?.trim()) {
      return json({ error: 'submissionId is required.' }, 400)
    }

    const { data: visibleSubmission, error: visibleSubmissionError } = await userClient
      .from('submissions')
      .select('id, student_id, assignment_id')
      .eq('id', payload.submissionId)
      .maybeSingle()

    if (visibleSubmissionError || !visibleSubmission) {
      return json({ error: 'Current user cannot access this submission.' }, 403)
    }

    const submission = visibleSubmission as SubmissionRecord

    const context = await fetchSubmissionReviewContext({
      adminClient,
      encryptionSecret,
      submission,
      requestedBy: user.id,
    })

    const { data: activeMembership, error: activeMembershipError } = await userClient
      .from('memberships')
      .select('id')
      .eq('user_id', user.id)
      .eq('school_id', context.assignment.school_id)
      .eq('status', 'active')
      .maybeSingle()

    const canTriggerReview =
      submission.student_id === user.id || Boolean(activeMembership && !activeMembershipError)

    if (!canTriggerReview) {
      return json({ error: 'Current user is not allowed to trigger this review.' }, 403)
    }

    if (context.existingResult === 'teacher-review') {
      return json({
        status: 'completed',
        message: '老师已经完成最终点评，这条提交不会再被 AI 覆盖。',
      })
    }

    const queueResult = await queueSubmissionReview({
      adminClient,
      schoolConfig: context.schoolConfig,
      submission,
      assignment: context.assignment,
      existingJob: context.existingJob,
      requestedBy: user.id,
    })

    if (
      queueResult.status === 'processing' ||
      (context.existingJob?.status === 'processing')
    ) {
      return json({
        status: queueResult.status,
        message: queueResult.message,
      })
    }

    const immediateResult = await processSubmissionReview({
      adminClient,
      schoolConfig: context.schoolConfig,
      encryptionSecret,
      submission,
      assignment: context.assignment,
      items: context.items,
      audioAsset: context.audioAsset,
      existingJob: queueResult.job ?? context.existingJob,
      requestedBy: user.id,
    })

    return json({
      status: immediateResult.status,
      message:
        immediateResult.status === 'completed'
          ? 'AI 初评已完成，学生端刷新后即可查看。'
          : immediateResult.message ?? queueResult.message,
    })
  } catch (error) {
    console.error('ai-review-submission failed', error)
    return json(
      {
        error: error instanceof Error ? error.message : 'Unexpected AI review error.',
      },
      500,
    )
  }
})
