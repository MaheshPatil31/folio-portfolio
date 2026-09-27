export type SocialLink = { id: string; platform: string; url: string }
export type Project = { id: string; title: string; description: string; cover: string; gallery?: string[]; category: string; year: string; published: boolean; role: string; technologies: string[]; demoUrl?: string; repoUrl?: string }
export type Profile = { id: string; slug: string; name: string; headline: string; bio: string; location: string; avatar: string; email: string; emailPublic: boolean; availability: boolean; published: boolean; skills: string[]; socials: SocialLink[]; projects: Project[]; experience: string; education: string }

export const emptyProfile: Profile = {
  id: '', slug: '', name: '', headline: '', bio: '', location: '', avatar: '', email: '', emailPublic: false, availability: false, published: false,
  skills: [], socials: [], projects: [], experience: '', education: '',
}
