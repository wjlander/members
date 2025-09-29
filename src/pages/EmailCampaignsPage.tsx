import React, { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../lib/supabase'
import { Mail, Send, Calendar, Users, Eye } from 'lucide-react'
import LoadingSpinner from '../components/LoadingSpinner'

interface EmailCampaign {
  id: string
  subject: string
  content: string
  status: string
  recipient_count: number
  delivered_count: number
  opened_count: number
  clicked_count: number
  sent_at: string | null
  created_at: string
}

export default function EmailCampaignsPage() {
  const { user } = useAuth()
  const [campaigns, setCampaigns] = useState<EmailCampaign[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (user?.association_id) {
      loadCampaigns()
    }
  }, [user])

  const loadCampaigns = async () => {
    try {
      const { data, error } = await supabase
        .from('email_campaigns')
        .select('*')
        .eq('association_id', user?.association_id)
        .order('created_at', { ascending: false })

      if (error) {
        console.error('Error loading campaigns:', error)
      } else {
        setCampaigns(data || [])
      }
    } catch (error) {
      console.error('Error loading campaigns:', error)
    } finally {
      setLoading(false)
    }
  }

  const getStatusBadge = (status: string) => {
    const statusStyles = {
      draft: 'bg-gray-100 text-gray-800',
      sending: 'bg-blue-100 text-blue-800',
      sent: 'bg-green-100 text-green-800',
      failed: 'bg-red-100 text-red-800'
    }

    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
        statusStyles[status as keyof typeof statusStyles] || statusStyles.draft
      }`}>
        {status}
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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Email Campaigns</h1>
          <p className="text-gray-600">View email campaigns and their performance</p>
        </div>
      </div>

      {/* Campaigns List */}
      <div className="space-y-4">
        {campaigns.map((campaign) => (
          <div key={campaign.id} className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="flex-shrink-0">
                  <div className="h-10 w-10 bg-primary-100 rounded-lg flex items-center justify-center">
                    <Mail className="h-5 w-5 text-primary-600" />
                  </div>
                </div>
                <div className="flex-1">
                  <div className="flex items-center space-x-2">
                    <h3 className="text-lg font-semibold text-gray-900">{campaign.subject}</h3>
                    {getStatusBadge(campaign.status)}
                  </div>
                  <p className="text-gray-600 text-sm mt-1">
                    {campaign.content.length > 100 
                      ? `${campaign.content.substring(0, 100)}...`
                      : campaign.content
                    }
                  </p>
                  <div className="flex items-center mt-2 space-x-4 text-sm text-gray-500">
                    <div className="flex items-center">
                      <Users className="h-4 w-4 mr-1" />
                      <span>{campaign.recipient_count} recipients</span>
                    </div>
                    {campaign.sent_at && (
                      <div className="flex items-center">
                        <Calendar className="h-4 w-4 mr-1" />
                        <span>Sent {new Date(campaign.sent_at).toLocaleDateString()}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {campaign.status === 'sent' && (
                <div className="text-right">
                  <div className="text-sm text-gray-500">Performance</div>
                  <div className="flex space-x-4 mt-1">
                    <div className="text-center">
                      <div className="text-lg font-semibold text-green-600">
                        {campaign.delivered_count}
                      </div>
                      <div className="text-xs text-gray-500">Delivered</div>
                    </div>
                    <div className="text-center">
                      <div className="text-lg font-semibold text-blue-600">
                        {campaign.opened_count}
                      </div>
                      <div className="text-xs text-gray-500">Opened</div>
                    </div>
                    <div className="text-center">
                      <div className="text-lg font-semibold text-purple-600">
                        {campaign.clicked_count}
                      </div>
                      <div className="text-xs text-gray-500">Clicked</div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}

        {campaigns.length === 0 && (
          <div className="card text-center py-12">
            <Send className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No email campaigns</h3>
            <p className="mt-1 text-sm text-gray-500">
              No email campaigns have been sent to your association yet.
            </p>
          </div>
        )}
      </div>
    </div>
  )
}