import React, { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../lib/supabase'
import { Users, Mail, Calendar, DollarSign, TrendingUp, Clock } from 'lucide-react'
import LoadingSpinner from '../components/LoadingSpinner'

interface DashboardStats {
  totalMembers: number
  activeMembers: number
  pendingMembers: number
  mailingLists: number
  recentCampaigns: number
}

interface RecentActivity {
  id: string
  type: string
  description: string
  timestamp: string
}

export default function DashboardPage() {
  const { user } = useAuth()
  const [stats, setStats] = useState<DashboardStats>({
    totalMembers: 0,
    activeMembers: 0,
    pendingMembers: 0,
    mailingLists: 0,
    recentCampaigns: 0
  })
  const [recentActivity, setRecentActivity] = useState<RecentActivity[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (user?.association_id) {
      loadDashboardData()
    }
  }, [user])

  const loadDashboardData = async () => {
    try {
      // Load member statistics
      const { data: members } = await supabase
        .from('members')
        .select('status')
        .eq('association_id', user?.association_id)

      const totalMembers = members?.length || 0
      const activeMembers = members?.filter(m => m.status === 'active').length || 0
      const pendingMembers = members?.filter(m => m.status === 'pending').length || 0

      // Load mailing lists count
      const { data: mailingLists } = await supabase
        .from('mailing_lists')
        .select('id')
        .eq('association_id', user?.association_id)
        .eq('status', 'active')

      // Load recent campaigns count
      const { data: campaigns } = await supabase
        .from('email_campaigns')
        .select('id')
        .eq('association_id', user?.association_id)
        .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())

      setStats({
        totalMembers,
        activeMembers,
        pendingMembers,
        mailingLists: mailingLists?.length || 0,
        recentCampaigns: campaigns?.length || 0
      })

      // Mock recent activity for now
      setRecentActivity([
        {
          id: '1',
          type: 'member_joined',
          description: `${pendingMembers} new member applications`,
          timestamp: new Date().toISOString()
        },
        {
          id: '2',
          type: 'campaign_sent',
          description: `${campaigns?.length || 0} email campaigns this month`,
          timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
        }
      ])

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
      icon: TrendingUp,
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
    }
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-600">Welcome back, {user?.name}</p>
        </div>
        <div className="text-sm text-gray-500">
          {user?.association_name}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((stat) => {
          const Icon = stat.icon
          return (
            <div key={stat.name} className="card">
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

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h3>
          <div className="space-y-3">
            {recentActivity.map((activity) => (
              <div key={activity.id} className="flex items-center space-x-3">
                <div className="flex-shrink-0">
                  <div className="h-2 w-2 bg-primary-600 rounded-full"></div>
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

        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
          <div className="space-y-3">
            <button className="w-full text-left p-3 rounded-lg border border-gray-200 hover:border-primary-300 hover:bg-primary-50 transition-colors duration-200">
              <div className="flex items-center">
                <Users className="h-5 w-5 text-primary-600 mr-3" />
                <div>
                  <p className="font-medium text-gray-900">Update Profile</p>
                  <p className="text-sm text-gray-500">Manage your member information</p>
                </div>
              </div>
            </button>
            
            <button className="w-full text-left p-3 rounded-lg border border-gray-200 hover:border-primary-300 hover:bg-primary-50 transition-colors duration-200">
              <div className="flex items-center">
                <Mail className="h-5 w-5 text-primary-600 mr-3" />
                <div>
                  <p className="font-medium text-gray-900">Manage Subscriptions</p>
                  <p className="text-sm text-gray-500">Update mailing list preferences</p>
                </div>
              </div>
            </button>
          </div>
        </div>
      </div>

      {/* Member Status */}
      {user?.member_status === 'pending' && (
        <div className="card border-yellow-200 bg-yellow-50">
          <div className="flex items-center">
            <Clock className="h-6 w-6 text-yellow-600 mr-3" />
            <div>
              <h3 className="text-lg font-semibold text-yellow-800">Account Pending Approval</h3>
              <p className="text-yellow-700">
                Your membership application is being reviewed. You'll receive an email once approved.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}