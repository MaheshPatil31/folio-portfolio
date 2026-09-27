import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined
export const configured = Boolean(url && key)
export const supabase = configured ? createClient(url!, key!) : null

export function profileToRow(profile: any) {
  const { emailPublic, ...rest } = profile
  return { ...rest, email_public: emailPublic }
}

export async function uploadImage(file: File, userId: string) {
  if (!supabase) throw new Error('Connect Supabase in .env.local to enable image storage.')
  if (!file.type.startsWith('image/')) throw new Error('Please choose an image file.')
  if (file.size > 5 * 1024 * 1024) throw new Error('Images need to be smaller than 5 MB.')
  const ext = file.name.split('.').pop()?.replace(/[^a-z0-9]/gi, '') || 'jpg'
  const path = `${userId}/${crypto.randomUUID()}.${ext}`
  const { error } = await supabase.storage.from('portfolio-images').upload(path, file, { upsert: false, contentType: file.type })
  if (error) throw error
  const { data } = supabase.storage.from('portfolio-images').getPublicUrl(path)
  return data.publicUrl
}
