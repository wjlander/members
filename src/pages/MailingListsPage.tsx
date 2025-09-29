import React, { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../lib/supabase'
import { Mail, Users, Settings, Check, X } from 'lucide-react'
import LoadingSpinner from '../components/LoadingSpinner'

interface MailingList {
  id: string
  name: string
  description: string | null
  type: string
  auto_subscribe_new_members: boolean
  subscriber_count?: number
  is_subscribed?: boolean
}

export default function MailingListsPage() {
  const { user } = useAuth()
  const [mailingLists, setMailingLists] = useState<MailingList[]>([])
  const [loading, setLoading] = useState(true)
  const [updating, setUpdating] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    if (user?.association_id) {
      loadMailingLists()
    }
  }, [user])

  const loadMailingLists = async () => {
    try {
      // Get mailing lists for the association
      const { data: lists, error: listsError } = await supabase
        .from('mailing_lists')
        .select('*')
        .eq('association_id', user?.association_id)
        .eq('status', 'active')
        .order('name')

      if (listsError) {
        setError('Failed to load mailing lists')
        return
      }

      // Get current member's subscriptions
      const { data: member } = await supabase
        .from('members')
        .select('id')
        .eq('user_id', user?.id)
        .single()

      if (member) {
        const { data: subscriptions } = await supabase
          .from('mailing_list_subscriptions')
          .select('mailing_list_id')
          .eq('member_id', member.id)
          .eq('is_active', true)

        const subscribedListIds = new Set(subscriptions?.map(s => s.mailing_list_id) || [])

        // Get subscriber counts for each list
        const listsWithSubscriptions = await Promise.all(
          (lists || []).map(async (list) => {
            const { count } = await supabase
              .from('mailing_list_subscriptions')
              .select('*', { count: 'exact', head: true })
              .eq('mailing_list_id', list.id)
              .eq('is_active', true)

            return {
              ...list,
              subscriber_count: count || 0,
              is_subscribed: subscribedListIds.has(list.id)
            }
          })
        )

        setMailingLists(listsWithSubscriptions)
      }
    } catch (error) {
      console.error('Error loading mailing lists:', error)
      setError('Failed to load mailing lists')
    } finally {
      setLoading(false)
    }
  }

  const toggleSubscription = async (listId: string, isCurrentlySubscribed: boolean) => {
    setUpdating(listId)
    setError('')
    setSuccess('')

    try {
      // Get current member
      const { data: member } = await supabase
        .from('members')
        .select('id')
        .eq('user_id', user?.id)
        .single()

      if (!member) {
        setError('Member record not found')
        return
      }

      if (isCurrentlySubscribed) {
        // Unsubscribe
        const { error } = await supabase
          .from('mailing_list_subscriptions')
          .update({ 
            is_active: false,
            unsubscribed_at: new Date().toISOString()
          })
          .eq('mailing_list_id', listId)
          .eq('member_id', member.id)

        if (error) {
          setError('Failed to unsubscribe')
        } else {
          setSuccess('Successfully unsubscribed')
        }
      } else {
        // Subscribe (upsert to handle re-subscription)
        const { error } = await supabase
          .from('mailing_list_subscriptions')
          .upsert({
            mailing_list_id: listId,
            member_id: member.id,
            is_active: true,
            subscribed_at: new Date().toISOString(),
            unsubscribed_at: null
          })

        if (error) {
          setError('Failed to subscribe')
        } else {
          setSuccess('Successfully subscribed')
        }
      }

      // Reload the lists to update subscription status
      await loadMailingLists()
    } catch (error) {
      console.error('Error toggling subscription:', error)
      setError('Failed to update subscription')
    } finally {
      setUpdating(null)
    }
  }

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'newsletter':
        return <Mail className="h-5 w-5" />
      case 'announcements':
        return <Settings className="h-5 w-5" />
      case 'events':
        return <Calendar className="h-5 w-5" />
      default:
        return <Mail className="h-5 w-5" />
    }
  }

  const getTypeBadge = (type: string) => {
    const typeStyles = {
      newsletter: 'bg-blue-100 text-blue-800',
      announcements: 'bg-red-100 text-red-800',
      events: 'bg-green-100 text-green-800',
      general: 'bg-gray-100 text-gray-800',
      urgent: 'bg-orange-100 text-orange-800',
      social: 'bg-purple-100 text-purple-800'
    }

    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
        typeStyles[type as keyof typeof typeStyles] || typeStyles.general
      }`}>
        {type}
      </span>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Mailing Lists</h1>
        <p className="text-gray-600">Manage your email subscriptions</p>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          {error}
        </div>
      )}

      {success && (
        <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg">
          {success}
        </div>
      )}

      {/* Mailing Lists */}
      <div className="space-y-4">
        {mailingLists.map((list) => (
          <div key={list.id} className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="flex-shrink-0">
                  <div className="h-10 w-10 bg-primary-100 rounded-lg flex items-center justify-center">
                    {getTypeIcon(list.type)}
                  </div>
                </div>
                <div className="flex-1">
                  <div className="flex items-center space-x-2">
                    <h3 className="text-lg font-semibold text-gray-900">{list.name}</h3>
                    {getTypeBadge(list.type)}
                  </div>
                  <p className="text-gray-600 text-sm mt-1">
                    {list.description || 'No description available'}
                  </p>
                  <div className="flex items-center mt-2 text-sm text-gray-500">
                    <Users className="h-4 w-4 mr-1" />
                    <span>{list.subscriber_count || 0} subscribers</span>
                  </div>
                </div>
              </div>

              <div className="flex items-center space-x-3">
                {list.is_subscribed ? (
                  <div className="flex items-center text-green-600">
                    <Check className="h-4 w-4 mr-1" />
                    <span className="text-sm font-medium">Subscribed</span>
                  </div>
                ) : (
                  <div className="flex items-center text-gray-400">
                    <X className="h-4 w-4 mr-1" />
                    <span className="text-sm">Not subscribed</span>
                  </div>
                )}

                <button
                  onClick={() => toggleSubscription(list.id, list.is_subscribed || false)}
                  disabled={updating === list.id}
                  className={`px-4 py-2 rounded-lg font-medium text-sm transition-colors duration-200 ${
                    list.is_subscribed
                      ? 'bg-red-100 text-red-700 hover:bg-red-200'
                      : 'bg-primary-100 text-primary-700 hover:bg-primary-200'
                  } disabled:opacity-50`}
                >
                  {updating === list.id ? (
                    <LoadingSpinner size="sm" />
                  ) : list.is_subscribed ? (
                    'Unsubscribe'
                  ) : (
                    'Subscribe'
                  )}
                </button>
              </div>
            </div>
          </div>
        ))}

        {mailingLists.length === 0 && (
          <div className="card text-center py-12">
            <Mail className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No mailing lists</h3>
            <p className="mt-1 text-sm text-gray-500">
              No mailing lists are available for your association yet.
            </p>
          </div>
        )}
      </div>
    </div>
  )
}