import React, { useState, useEffect } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import { supabase } from '../../lib/supabase'
import { Mail, Plus, Users, Settings, Edit, Trash2 } from 'lucide-react'
import LoadingSpinner from '../../components/LoadingSpinner'

interface MailingList {
  id: string
  name: string
  description: string | null
  type: string
  auto_subscribe_new_members: boolean
  status: string
  subscriber_count?: number
}

export default function AdminMailingLists() {
  const { user } = useAuth()
  const [mailingLists, setMailingLists] = useState<MailingList[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    type: 'general',
    auto_subscribe_new_members: false
  })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadMailingLists()
  }, [user])

  const loadMailingLists = async () => {
    try {
      let query = supabase.from('mailing_lists').select('*')

      // Super admin sees all lists, regular admin sees only their association
      if (user?.role !== 'super_admin' && user?.association_id) {
        query = query.eq('association_id', user.association_id)
      }

      const { data: lists, error } = await query.order('name')

      if (error) {
        setError('Failed to load mailing lists')
        return
      }

      // Get subscriber counts for each list
      const listsWithCounts = await Promise.all(
        (lists || []).map(async (list) => {
          const { count } = await supabase
            .from('mailing_list_subscriptions')
            .select('*', { count: 'exact', head: true })
            .eq('mailing_list_id', list.id)
            .eq('is_active', true)

          return {
            ...list,
            subscriber_count: count || 0
          }
        })
      )

      setMailingLists(listsWithCounts)
    } catch (error) {
      console.error('Error loading mailing lists:', error)
      setError('Failed to load mailing lists')
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
        .from('mailing_lists')
        .insert({
          association_id: user?.association_id,
          name: formData.name,
          description: formData.description || null,
          type: formData.type,
          auto_subscribe_new_members: formData.auto_subscribe_new_members,
          status: 'active'
        })

      if (error) {
        setError(error.message)
      } else {
        setSuccess('Mailing list created successfully!')
        setShowCreateForm(false)
        setFormData({
          name: '',
          description: '',
          type: 'general',
          auto_subscribe_new_members: false
        })
        await loadMailingLists()
      }
    } catch (error) {
      setError('Failed to create mailing list')
    } finally {
      setSaving(false)
    }
  }

  const deleteMailingList = async (listId: string) => {
    if (!confirm('Are you sure you want to delete this mailing list?')) {
      return
    }

    try {
      const { error } = await supabase
        .from('mailing_lists')
        .delete()
        .eq('id', listId)

      if (error) {
        setError('Failed to delete mailing list')
      } else {
        setSuccess('Mailing list deleted successfully!')
        await loadMailingLists()
      }
    } catch (error) {
      setError('Failed to delete mailing list')
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

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Mailing Lists</h1>
          <p className="text-gray-600">Create and manage email lists for your association</p>
        </div>
        <button
          onClick={() => setShowCreateForm(true)}
          className="btn-admin flex items-center"
        >
          <Plus className="h-4 w-4 mr-2" />
          Create List
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
          <div className="bg-white p-6 rounded-xl shadow-lg max-w-md w-full">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold">Create Mailing List</h3>
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
                  List Name *
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="input-field"
                  placeholder="e.g., Monthly Newsletter"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="input-field"
                  rows={3}
                  placeholder="Describe the purpose of this mailing list"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Type *
                </label>
                <select
                  value={formData.type}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                  className="input-field"
                >
                  <option value="general">General</option>
                  <option value="newsletter">Newsletter</option>
                  <option value="announcements">Announcements</option>
                  <option value="events">Events</option>
                  <option value="urgent">Urgent</option>
                  <option value="social">Social</option>
                </select>
              </div>

              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="auto_subscribe"
                  checked={formData.auto_subscribe_new_members}
                  onChange={(e) => setFormData({ ...formData, auto_subscribe_new_members: e.target.checked })}
                  className="h-4 w-4 text-admin-600 focus:ring-admin-500 border-gray-300 rounded"
                />
                <label htmlFor="auto_subscribe" className="ml-2 block text-sm text-gray-900">
                  Auto-subscribe new members
                </label>
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
                    'Create List'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Mailing Lists */}
      <div className="space-y-4">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <LoadingSpinner size="lg" />
          </div>
        ) : (
          mailingLists.map((list) => (
            <div key={list.id} className="admin-card">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-4">
                  <div className="flex-shrink-0">
                    <div className="h-10 w-10 bg-admin-100 rounded-lg flex items-center justify-center">
                      <Mail className="h-5 w-5 text-admin-600" />
                    </div>
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center space-x-2">
                      <h3 className="text-lg font-semibold text-gray-900">{list.name}</h3>
                      {getTypeBadge(list.type)}
                      {list.auto_subscribe_new_members && (
                        <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Auto-subscribe
                        </span>
                      )}
                    </div>
                    <p className="text-gray-600 text-sm mt-1">
                      {list.description || 'No description'}
                    </p>
                    <div className="flex items-center mt-2 text-sm text-gray-500">
                      <Users className="h-4 w-4 mr-1" />
                      <span>{list.subscriber_count || 0} subscribers</span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center space-x-2">
                  <button
                    className="p-2 text-gray-600 hover:text-gray-900 rounded-lg hover:bg-gray-100"
                    title="Edit list"
                  >
                    <Edit className="h-4 w-4" />
                  </button>
                  <button
                    className="p-2 text-gray-600 hover:text-gray-900 rounded-lg hover:bg-gray-100"
                    title="Manage subscribers"
                  >
                    <Users className="h-4 w-4" />
                  </button>
                  <button
                    onClick={() => deleteMailingList(list.id)}
                    className="p-2 text-red-600 hover:text-red-900 rounded-lg hover:bg-red-100"
                    title="Delete list"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}

        {mailingLists.length === 0 && !loading && (
          <div className="admin-card text-center py-12">
            <Mail className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No mailing lists</h3>
            <p className="mt-1 text-sm text-gray-500">
              Create your first mailing list to start organizing your email communications.
            </p>
            <button
              onClick={() => setShowCreateForm(true)}
              className="mt-4 btn-admin flex items-center mx-auto"
            >
              <Plus className="h-4 w-4 mr-2" />
              Create Your First List
            </button>
          </div>
        )}
      </div>
    </div>
  )
}