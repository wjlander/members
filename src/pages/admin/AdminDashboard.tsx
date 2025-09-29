import React, { useState, useEffect } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import { supabase } from '../../lib/supabase'
import { Users, Mail, Send, TrendingUp, Clock, CheckCircle } from 'lucide-react'
import LoadingSpinner from '../../components/LoadingSpinner'

interface AdminStats {
  totalMembers: number
  activeMembers: number
  pendingMembers: number
  mailingLists: number
  emailCampaigns: number
  recentActivity: Array<{
    id: string
    type: string
    description: string
    timestamp: string
  }>
}

export default function AdminDashboard() {
  const { user } = useAuth()
  const [stats, setStats] = useState<AdminStats>({
    totalMembers: 0,
    activeMembers: 0,
    pendingMembers: 0,
    mailingLists: 0,
    emailCampaigns: 0,
    recentActivity: []
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadDashboardData()
  }, [user])

  const loadDashboardData = async () => {
    try {
      let associationFilter = user?.association_id

      // Super admin can see all data
      if (user?.role === 'super_admin') {
        associationFilter = undefined
      }

      // Load member statistics
      let membersQuery = supabase.from('members').select('status')
      if (associationFilter) {
        membersQuery = membersQuery.eq('association_id', associationFilter)
      }

      const { data: members } = await membersQuery

      const totalMembers = members?.length || 0
      const activeMembers = members?.filter(m => m.status === 'active').length || 0
      const pendingMembers = members?.filter(m => m.status === 'pending').length || 0

      // Load mailing lists count
      let listsQuery = supabase.from('mailing_lists').select('id').eq('status', 'active')
      if (associationFilter) {
        listsQuery = listsQuery.eq('association_id', associationFilter)
      }

      const { data: mailingLists } = await listsQuery

      // Load email campaigns count
      let campaignsQuery = supabase.from('email_campaigns').select('id')
      if (associationFilter) {
        campaignsQuery = campaignsQuery.eq('association_id', associationFilter)
      }

      const { data: campaigns } = await campaignsQuery

      // Generate recent activity
      const recentActivity = [
        {
          id: '1',
          type: 'members',
          description: `${pendingMembers} members awaiting approval`,
          timestamp: new Date().toISOString()
        },
        {
          id: '2',
          type: 'campaigns',
          description: `${campaigns?.length || 0} total email campaigns`,
          timestamp: new Date().toISOString()
        },
        {
          id: '3',
          type: 'lists',
          description: `${mailingLists?.length || 0} active mailing lists`,
          timestamp: new Date().toISOString()
        }
      ]

      setStats({
        totalMembers,
        activeMembers,
        pendingMembers,
        mailingLists: mailingLists?.length || 0,
        emailCampaigns: campaigns?.length || 0,
        recentActivity
      })

    } catch (error) {
      console.error('Error loading dashboard data:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  const statCards = [
    {
      name: 'Total Members',
      value: stats.totalMembers,
      icon: Users,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50'
    },
    {
      name: 'Active Members',
      value: stats.activeMembers,
      icon: CheckCircle,
      color: 'text-green-600',
      bgColor: 'bg-green-50'
    },
    {
      name: 'Pending Approval',
      value: stats.pendingMembers,
      icon: Clock,
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-50'
    },
    {
      name: 'Mailing Lists',
      value: stats.mailingLists,
      icon: Mail,
      color: 'text-purple-600',
      bgColor: 'bg-purple-50'
    },
    {
      name: 'Email Campaigns',
      value: stats.emailCampaigns,
      icon: Send,
      color: 'text-indigo-600',
      bgColor: 'bg-indigo-50'
    }
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
          <p className="text-gray-600">
            {user?.role === 'super_admin' 
              ? 'System-wide overview and management'
              : `Managing ${user?.association_name}`
            }
          </p>
        </div>
        <div className="text-sm text-gray-500">
          Last updated: {new Date().toLocaleTimeString()}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
        {statCards.map((stat) => {
          const Icon = stat.icon
          return (
            <div key={stat.name} className="admin-card">
              <div className="flex items-center">
                <div className={`p-3 rounded-lg ${stat.bgColor}`}>
                  <Icon className={`h-6 w-6 ${stat.color}`} />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">{stat.name}</p>
                  <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Recent Activity & Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="admin-card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h3>
          <div className="space-y-3">
            {stats.recentActivity.map((activity) => (
              <div key={activity.id} className="flex items-center space-x-3">
                <div className="flex-shrink-0">
                  <div className="h-2 w-2 bg-admin-600 rounded-full"></div>
                </div>
                <div className="flex-1">
                  <p className="text-sm text-gray-900">{activity.description}</p>
                  <p className="text-xs text-gray-500">
                    {new Date(activity.timestamp).toLocaleDateString()}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
          <div className="space-y-3">
            <button className="w-full text-left p-3 rounded-lg border border-gray-200 hover:border-admin-300 hover:bg-admin-50 transition-colors duration-200">
              <div className="flex items-center">
                <Users className="h-5 w-5 text-admin-600 mr-3" />
                <div>
                  <p className="font-medium text-gray-900">Approve Members</p>
                  <p className="text-sm text-gray-500">{stats.pendingMembers} pending approval</p>
                </div>
              </div>
            </button>
            
            <button className="w-full text-left p-3 rounded-lg border border-gray-200 hover:border-admin-300 hover:bg-admin-50 transition-colors duration-200">
              <div className="flex items-center">
                <Send className="h-5 w-5 text-admin-600 mr-3" />
                <div>
                  <p className="font-medium text-gray-900">Create Campaign</p>
                  <p className="text-sm text-gray-500">Send email to members</p>
                </div>
              </div>
            </button>

            <button className="w-full text-left p-3 rounded-lg border border-gray-200 hover:border-admin-300 hover:bg-admin-50 transition-colors duration-200">
              <div className="flex items-center">
                <Mail className="h-5 w-5 text-admin-600 mr-3" />
                <div>
                  <p className="font-medium text-gray-900">Manage Lists</p>
                  <p className="text-sm text-gray-500">Create and edit mailing lists</p>
                </div>
              </div>
            </button>
          </div>
        </div>
      </div>

      {/* Performance Overview */}
      {stats.emailCampaigns > 0 && (
        <div className="admin-card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Email Performance Overview</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">
                {campaigns.reduce((sum, c) => sum + c.delivered_count, 0)}
              </div>
              <div className="text-sm text-gray-500">Total Delivered</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">
                {campaigns.reduce((sum, c) => sum + c.opened_count, 0)}
              </div>
              <div className="text-sm text-gray-500">Total Opened</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">
                {campaigns.reduce((sum, c) => sum + c.clicked_count, 0)}
              </div>
              <div className="text-sm text-gray-500">Total Clicked</div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}