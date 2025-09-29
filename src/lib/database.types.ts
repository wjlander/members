export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      associations: {
        Row: {
          id: string
          name: string
          code: string
          description: string | null
          settings: Json
          status: 'active' | 'inactive'
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          name: string
          code: string
          description?: string | null
          settings?: Json
          status?: 'active' | 'inactive'
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          name?: string
          code?: string
          description?: string | null
          settings?: Json
          status?: 'active' | 'inactive'
          created_at?: string
          updated_at?: string
        }
      }
      users: {
        Row: {
          id: string
          email: string
          name: string
          role: 'super_admin' | 'admin' | 'member'
          association_id: string | null
          avatar_url: string | null
          email_verified: boolean
          last_login: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          email: string
          name: string
          role?: 'super_admin' | 'admin' | 'member'
          association_id?: string | null
          avatar_url?: string | null
          email_verified?: boolean
          last_login?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          name?: string
          role?: 'super_admin' | 'admin' | 'member'
          association_id?: string | null
          avatar_url?: string | null
          email_verified?: boolean
          last_login?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      members: {
        Row: {
          id: string
          user_id: string
          association_id: string
          member_id: string
          name: string
          email: string
          phone: string | null
          address: string | null
          date_of_birth: string | null
          status: 'pending' | 'active' | 'inactive' | 'suspended'
          membership_type: 'regular' | 'premium' | 'student' | 'senior' | 'honorary'
          join_date: string
          notes: string | null
          documents: Json
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          association_id: string
          member_id?: string
          name: string
          email: string
          phone?: string | null
          address?: string | null
          date_of_birth?: string | null
          status?: 'pending' | 'active' | 'inactive' | 'suspended'
          membership_type?: 'regular' | 'premium' | 'student' | 'senior' | 'honorary'
          join_date?: string
          notes?: string | null
          documents?: Json
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          association_id?: string
          member_id?: string
          name?: string
          email?: string
          phone?: string | null
          address?: string | null
          date_of_birth?: string | null
          status?: 'pending' | 'active' | 'inactive' | 'suspended'
          membership_type?: 'regular' | 'premium' | 'student' | 'senior' | 'honorary'
          join_date?: string
          notes?: string | null
          documents?: Json
          created_at?: string
          updated_at?: string
        }
      }
      mailing_lists: {
        Row: {
          id: string
          association_id: string
          name: string
          description: string | null
          type: 'general' | 'announcements' | 'events' | 'newsletter' | 'urgent' | 'social'
          moderator_email: string | null
          auto_subscribe_new_members: boolean
          status: 'active' | 'inactive'
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          association_id: string
          name: string
          description?: string | null
          type?: 'general' | 'announcements' | 'events' | 'newsletter' | 'urgent' | 'social'
          moderator_email?: string | null
          auto_subscribe_new_members?: boolean
          status?: 'active' | 'inactive'
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          association_id?: string
          name?: string
          description?: string | null
          type?: 'general' | 'announcements' | 'events' | 'newsletter' | 'urgent' | 'social'
          moderator_email?: string | null
          auto_subscribe_new_members?: boolean
          status?: 'active' | 'inactive'
          created_at?: string
          updated_at?: string
        }
      }
      mailing_list_subscriptions: {
        Row: {
          id: string
          mailing_list_id: string
          member_id: string
          subscribed_at: string
          unsubscribed_at: string | null
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          mailing_list_id: string
          member_id: string
          subscribed_at?: string
          unsubscribed_at?: string | null
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          mailing_list_id?: string
          member_id?: string
          subscribed_at?: string
          unsubscribed_at?: string | null
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
      }
      email_campaigns: {
        Row: {
          id: string
          association_id: string
          mailing_list_id: string | null
          sender_id: string
          subject: string
          content: string
          template_name: string | null
          scheduled_at: string | null
          sent_at: string | null
          status: string
          recipient_count: number
          delivered_count: number
          opened_count: number
          clicked_count: number
          bounced_count: number
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          association_id: string
          mailing_list_id?: string | null
          sender_id: string
          subject: string
          content: string
          template_name?: string | null
          scheduled_at?: string | null
          sent_at?: string | null
          status?: string
          recipient_count?: number
          delivered_count?: number
          opened_count?: number
          clicked_count?: number
          bounced_count?: number
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          association_id?: string
          mailing_list_id?: string | null
          sender_id?: string
          subject?: string
          content?: string
          template_name?: string | null
          scheduled_at?: string | null
          sent_at?: string | null
          status?: string
          recipient_count?: number
          delivered_count?: number
          opened_count?: number
          clicked_count?: number
          bounced_count?: number
          created_at?: string
          updated_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}