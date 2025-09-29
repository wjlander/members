import React, { useState, useEffect } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import { supabase } from '../../lib/supabase'
import { Settings, Save, Building, Mail, Users, Shield } from 'lucide-react'
import LoadingSpinner from '../../components/LoadingSpinner'

interface Association {
  id: string
  name: string
  code: string
  description: string | null
  settings: any
  status: string
}

export default function AdminSettings() {
  const { user } = useAuth()
  const [association, setAssociation] = useState<Association | null>(null)
  const [formData, setFormData] = useState({
    name: '',
    code: '',
    description: '',
    settings: {
      auto_approve_members: false,
      require_phone: false,
      require_address: false,
      email_notifications: true
    }
  })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    if (user?.association_id) {
      loadAssociation()
    }
  }, [user])

  const loadAssociation = async () => {
    try {
      const { data, error } = await supabase
        .from('associations')
        .select('*')
        .eq('id', user?.association_id)
        .single()

      if (error) {
        setError('Failed to load association settings')
      } else {
        setAssociation(data)
        setFormData({
          name: data.name,
          code: data.code,
          description: data.description || '',
          settings: {
            auto_approve_members: data.settings?.auto_approve_members || false,
            require_phone: data.settings?.require_phone || false,
            require_address: data.settings?.require_address || false,
            email_notifications: data.settings?.email_notifications !== false
          }
        })
      }
    } catch (error) {
      console.error('Error loading association:', error)
      setError('Failed to load association settings')
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
        .from('associations')
        .update({
          name: formData.name,
          code: formData.code,
          description: formData.description || null,
          settings: formData.settings
        })
        .eq('id', user?.association_id)

      if (error) {
        setError(error.message)
      } else {
        setSuccess('Settings updated successfully!')
        await loadAssociation()
      }
    } catch (error) {
      setError('Failed to update settings')
    } finally {
      setSaving(false)
    }
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    })
  }

  const handleSettingChange = (setting: string, value: boolean) => {
    setFormData({
      ...formData,
      settings: {
        ...formData.settings,
        [setting]: value
      }
    })
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (user?.role !== 'admin' && user?.role !== 'super_admin') {
    return (
      <div className="admin-card text-center py-12">
        <Shield className="mx-auto h-12 w-12 text-gray-400" />
        <h3 className="mt-2 text-sm font-medium text-gray-900">Access Denied</h3>
        <p className="mt-1 text-sm text-gray-500">
          You don't have permission to access settings.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Association Settings</h1>
        <p className="text-gray-600">Manage your association configuration</p>
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

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Basic Information */}
        <div className="admin-card">
          <div className="flex items-center mb-4">
            <Building className="h-5 w-5 text-admin-600 mr-2" />
            <h3 className="text-lg font-semibold text-gray-900">Basic Information</h3>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-2">
                Association Name *
              </label>
              <input
                id="name"
                name="name"
                type="text"
                required
                value={formData.name}
                onChange={handleInputChange}
                className="input-field"
              />
            </div>

            <div>
              <label htmlFor="code" className="block text-sm font-medium text-gray-700 mb-2">
                Association Code *
              </label>
              <input
                id="code"
                name="code"
                type="text"
                required
                value={formData.code}
                onChange={handleInputChange}
                className="input-field"
                placeholder="e.g., SBRA"
              />
            </div>
          </div>

          <div className="mt-6">
            <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              id="description"
              name="description"
              rows={3}
              value={formData.description}
              onChange={handleInputChange}
              className="input-field"
              placeholder="Describe your association"
            />
          </div>
        </div>

        {/* Member Settings */}
        <div className="admin-card">
          <div className="flex items-center mb-4">
            <Users className="h-5 w-5 text-admin-600 mr-2" />
            <h3 className="text-lg font-semibold text-gray-900">Member Settings</h3>
          </div>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">Auto-approve new members</h4>
                <p className="text-sm text-gray-500">Automatically approve member registrations</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.settings.auto_approve_members}
                  onChange={(e) => handleSettingChange('auto_approve_members', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-admin-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-admin-600"></div>
              </label>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">Require phone number</h4>
                <p className="text-sm text-gray-500">Make phone number mandatory during registration</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.settings.require_phone}
                  onChange={(e) => handleSettingChange('require_phone', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-admin-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-admin-600"></div>
              </label>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">Require address</h4>
                <p className="text-sm text-gray-500">Make address mandatory during registration</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.settings.require_address}
                  onChange={(e) => handleSettingChange('require_address', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-admin-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-admin-600"></div>
              </label>
            </div>
          </div>
        </div>

        {/* Email Settings */}
        <div className="admin-card">
          <div className="flex items-center mb-4">
            <Mail className="h-5 w-5 text-admin-600 mr-2" />
            <h3 className="text-lg font-semibold text-gray-900">Email Settings</h3>
          </div>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-medium text-gray-900">Email notifications</h4>
                <p className="text-sm text-gray-500">Send automated email notifications to members</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.settings.email_notifications}
                  onChange={(e) => handleSettingChange('email_notifications', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-admin-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-admin-600"></div>
              </label>
            </div>
          </div>
        </div>

        {/* Save Button */}
        <div className="flex justify-end">
          <button
            type="submit"
            disabled={saving}
            className="btn-admin flex items-center"
          >
            {saving ? (
              <>
                <LoadingSpinner size="sm" className="mr-2" />
                Saving...
              </>
            ) : (
              <>
                <Save className="h-4 w-4 mr-2" />
                Save Settings
              </>
            )}
          </button>
        </div>
      </form>
    </div>
  )
}