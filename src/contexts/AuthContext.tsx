import React, { createContext, useContext, useEffect, useState } from 'react'
import { User, Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

interface AuthUser extends User {
  role?: string
  association_id?: string
  association_name?: string
  member_id?: string
  member_status?: string
}

interface AuthContextType {
  user: AuthUser | null
  session: Session | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<{ error?: string }>
  signUp: (email: string, password: string, name: string, associationId: string) => Promise<{ error?: string }>
  signOut: () => Promise<void>
  updateProfile: (updates: Partial<AuthUser>) => Promise<{ error?: string }>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      if (session?.user) {
        loadUserProfile(session.user)
      } else {
        setLoading(false)
      }
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        setSession(session)
        if (session?.user) {
          await loadUserProfile(session.user)
        } else {
          setUser(null)
          setLoading(false)
        }
      }
    )

    return () => subscription.unsubscribe()
  }, [])

  const loadUserProfile = async (authUser: User) => {
    try {
      // Get user profile with association and member info
      const { data: userProfile, error: userError } = await supabase
        .from('users')
        .select(`
          *,
          associations (
            id,
            name,
            code
          ),
          members (
            id,
            member_id,
            status
          )
        `)
        .eq('id', authUser.id)
        .single()

      if (userError) {
        console.error('Error loading user profile:', userError)
        setUser(authUser as AuthUser)
      } else {
        const enhancedUser: AuthUser = {
          ...authUser,
          role: userProfile.role,
          association_id: userProfile.association_id,
          association_name: userProfile.associations?.name,
          member_id: userProfile.members?.[0]?.member_id,
          member_status: userProfile.members?.[0]?.status
        }
        setUser(enhancedUser)
      }
    } catch (error) {
      console.error('Error in loadUserProfile:', error)
      setUser(authUser as AuthUser)
    } finally {
      setLoading(false)
    }
  }

  const signIn = async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      })

      if (error) {
        return { error: error.message }
      }

      return {}
    } catch (error) {
      return { error: 'An unexpected error occurred' }
    }
  }

  const signUp = async (email: string, password: string, name: string, associationId: string) => {
    try {
      // First create the auth user
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password
      })

      if (authError) {
        return { error: authError.message }
      }

      if (!authData.user) {
        return { error: 'Failed to create user account' }
      }

      // Create user profile
      const { error: userError } = await supabase
        .from('users')
        .insert({
          id: authData.user.id,
          email,
          name,
          role: 'member',
          association_id: associationId
        })

      if (userError) {
        return { error: userError.message }
      }

      // Create member record
      const { error: memberError } = await supabase
        .from('members')
        .insert({
          user_id: authData.user.id,
          association_id: associationId,
          name,
          email,
          status: 'pending'
        })

      if (memberError) {
        return { error: memberError.message }
      }

      return {}
    } catch (error) {
      return { error: 'Registration failed. Please try again.' }
    }
  }

  const signOut = async () => {
    await supabase.auth.signOut()
  }

  const updateProfile = async (updates: Partial<AuthUser>) => {
    try {
      if (!user) {
        return { error: 'No user logged in' }
      }

      const { error } = await supabase
        .from('users')
        .update(updates)
        .eq('id', user.id)

      if (error) {
        return { error: error.message }
      }

      // Reload user profile
      await loadUserProfile(user)
      return {}
    } catch (error) {
      return { error: 'Failed to update profile' }
    }
  }

  const value = {
    user,
    session,
    loading,
    signIn,
    signUp,
    signOut,
    updateProfile
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}