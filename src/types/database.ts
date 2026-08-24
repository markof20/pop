export type CircleRole = 'admin' | 'member'

export type Gender = 'uomo' | 'donna' | 'altro'

export interface Profile {
  id: string
  username: string
  avatar_url: string | null
  gender: Gender | null
  created_at: string
}

export type CircleCategory = 'amici' | 'normal' | 'hot'
export type CircleType = 'photo' | 'gif'

export interface Circle {
  id: string
  name: string
  invite_code: string
  time_window_minutes: number
  category: CircleCategory
  circle_type: CircleType
  created_by: string
  created_at: string
}

export interface CircleMember {
  circle_id: string
  user_id: string
  role: CircleRole
  joined_at: string
}

export interface CircleWithMembers extends Circle {
  member_count: number
  my_role: CircleRole
}

export type ChallengeStatus = 'pending' | 'active' | 'voting' | 'completed'
export type ChallengeSource = 'seed' | 'winner_choice'

export interface DailyChallenge {
  id: string
  circle_id: string
  challenge_date: string
  prompt_text: string
  proposed_by: string | null
  source: ChallengeSource
  activation_at: string
  window_end_at: string
  status: ChallengeStatus
  created_at: string
}

export interface ChallengeParticipant {
  daily_challenge_id: string
  user_id: string
  started_at: string
  window_end_at: string
}

export interface Photo {
  id: string
  daily_challenge_id: string
  user_id: string
  storage_path: string
  taken_at: string
  uploaded_at: string
  is_late: boolean
  retake_count: number
  created_at: string
}

export interface PhotoWithProfile extends Photo {
  profiles: Profile
  signed_url?: string
  top_pick_count?: number
}

export interface Reaction {
  id: string
  photo_id: string
  user_id: string
  emoji: string
  created_at: string
}

export interface TopPick {
  id: string
  daily_challenge_id: string
  voter_id: string
  photo_id: string
  created_at: string
}

export interface Comment {
  id: string
  photo_id: string
  user_id: string
  body: string
  created_at: string
}

export interface CommentWithProfile extends Comment {
  profiles: Profile
}

export type PartySessionStatus = 'checkin' | 'active' | 'completed'
export type PartyTaskStatus = 'pending' | 'revealed' | 'completed' | 'skipped'

export interface PartySession {
  id: string
  circle_id: string
  started_by: string
  status: PartySessionStatus
  current_task_id: string | null
  created_at: string
  completed_at: string | null
}

export interface PartyCheckin {
  session_id: string
  user_id: string
  checked_in_at: string
}

export interface PartyCheckinWithProfile extends PartyCheckin {
  profiles: Profile
}

export interface PartyTask {
  id: string
  session_id: string
  assignee_id: string
  prompt_id: string | null
  prompt_text: string
  status: PartyTaskStatus
  skipped: boolean
  revealed_at: string | null
  completed_at: string | null
}

export interface PartyRating {
  task_id: string
  voter_id: string
  value: number
  created_at: string
}

export interface PartyLeaderboardRow {
  assignee_id: string
  username: string
  tasks_completed: number
  upvotes: number
  downvotes: number
  net_score: number
}

export interface GifSession {
  id: string
  circle_id: string
  started_by: string
  prompt_text: string
  session_date: string
  created_at: string
}

export interface GifSubmission {
  id: string
  session_id: string
  user_id: string
  giphy_id: string
  gif_url: string
  submitted_at: string
}

export interface GifSubmissionResult {
  submission_id: string
  user_id: string
  username: string
  giphy_id: string
  gif_url: string
  vote_count: number
  submitted_at: string
}

export interface GifVote {
  session_id: string
  voter_id: string
  submission_id: string
  created_at: string
}
