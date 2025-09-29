import React, { useState, useEffect } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import { supabase } from '../../lib/supabase'
import { Send, Plus, Mail, Users, Calendar, BarChart3 } from 'lucide-react'
import LoadingSpinner from '../../components/LoadingSpinner'

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
  mailing_lists?: { name: string }
}

interface MailingList {
  id: string
  name: string
  type: string
}

export default function AdminEmailCampaigns() {
  const { user } = useAuth()
  const [campaigns, setCampaigns] = useState<EmailCampaign[]>([])
  const [mailingLists, setMailingLists] = useState<MailingList[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [formData, setFormData] = useState({
    subject: '',
    content: '',
    mailing_list_id: ''
  })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadData()
  }, [user])

  const loadData = async () => {
    try {
      // Load campaigns
      let campaignsQuery = supabase
        .from('email_campaigns')
        .select(`
          *,
          mailing_lists (name)
        `)

      // Super admin sees all campaigns, regular admin sees only their association
      if (user?.role !== 'super_admin' && user?.association_id) {
        campaignsQuery = campaignsQuery.eq('association_id', user.association_id)
      }

      const { data: campaignsData, error: campaignsError } = await campaignsQuery
        .order('created_at', { ascending: false })

      if (campaignsError) {
        setError('Failed to load email campaigns')
      } else {
        setCampaigns(campaignsData || [])
      }

      // Load mailing lists for the form
      let listsQuery = supabase
        .from('mailing_lists')
        .select('id, name, type')
        .eq('status', 'active')

      if (user?.role !== 'super_admin' && user?.association_id) {
        listsQuery = listsQuery.eq('association_id', user.association_id)
      }

      const { data: listsData, error: listsError } = await listsQuery.order('name')

      if (!listsError) {
        setMailingLists(listsData || [])
      }

    } catch (error) {
      console.error('Error loading data:', error)
      setError('Failed to load data')
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError('')
    setSuccess('')

    try {
      const { error } = await supabase
        .from('email_campaigns')
        .insert({
          association_id: user?.association_id,
          mailing_list_id: formData.mailing_list_id || null,
          sender_id: user?.id,
          subject: formData.subject,
          content: formData.content,
          status: 'draft'
        })

      if (error) {
        setError(error.message)
      } else {
        setSuccess('Email campaign created successfully!')
        setShowCreateForm(false)
        setFormData({
          subject: '',
          content: '',
          mailing_list_id: ''
        })
        await loadData()
      }
    } catch (error) {
      setError('Failed to create email campaign')
    } finally {
      setSaving(false)
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
          <p className="text-gray-600">Create and manage email campaigns</p>
        </div>
        <button
          onClick={() => setShowCreateForm(true)}
          className="btn-admin flex items-center"
        >
          <Plus className="h-4 w-4 mr-2" />
          Create Campaign
        </button>
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

      {/* Create Form Modal */}
      {showCreateForm && (
        <div className="fixed inset-0 bg-gray-900 bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white p-6 rounded-xl shadow-lg max-w-2xl w-full max-h-screen overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold">Create Email Campaign</h3>
              <button
                onClick={() => setShowCreateForm(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                ×
              </button>
            </div>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Subject *
                </label>
                <input
                  type="text"
                  required
                  value={formData.subject}
                  onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                  className="input-field"
                  placeholder="Email subject line"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Mailing List
                </label>
                <select
                  value={formData.mailing_list_id}
                  onChange={(e) => setFormData({ ...formData, mailing_list_id: e.target.value })}
                  className="input-field"
                >
                  <option value="">Send to all active members</option>
                  {mailingLists.map((list) => (
                    <option key={list.id} value={list.id}>
                      {list.name} ({list.type})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Content *
                </label>
                <textarea
                  required
                  value={formData.content}
                  onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                  className="input-field"
                  rows={8}
                  placeholder="Write your email content here..."
                />
              </div>

              <div className="flex justify-end space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowCreateForm(false)}
                  className="btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="btn-admin flex items-center"
                >
                  {saving ? (
                    <>
                      <LoadingSpinner size="sm" className="mr-2" />
                      Creating...
                    </>
                  ) : (
                    'Create Campaign'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Campaigns List */}
      <div className="space-y-4">
        {campaigns.map((campaign) => (
          <div key={campaign.id} className="admin-card">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="flex-shrink-0">
                  <div className="h-10 w-10 bg-admin-100 rounded-lg flex items-center justify-center">
                    <Send className="h-5 w-5 text-admin-600" />
                  </div>
                </div>
                <div className="flex-1">
                  <div className="flex items-center space-x-2">
                    <h3 className="text-lg font-semibold text-gray-900">{campaign.subject}</h3>
                    {getStatusBadge(campaign.status)}
                  </div>
                  <p className="text-gray-600 text-sm mt-1">
                    {campaign.mailing_lists?.name || 'All active members'}
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
                  <div className="text-sm text-gray-500 mb-1">Performance</div>
                  <div className="flex space-x-4">
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
          <div className="admin-card text-center py-12">
            <Send className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No email campaigns</h3>
            <p className="mt-1 text-sm text-gray-500">
              Create your first email campaign to communicate with your members.
            </p>
            <button
              onClick={() => setShowCreateForm(true)}
              className="mt-4 btn-admin flex items-center mx-auto"
            >
              <Plus className="h-4 w-4 mr-2" />
              Create Your First Campaign
            </button>
          </div>
        )}
      </div>
    </div>
  )
}