import React, { useState, useEffect } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import { supabase } from '../../lib/supabase'
import { Users, Search, Filter, Download, Check, X, Eye, Edit } from 'lucide-react'
import LoadingSpinner from '../../components/LoadingSpinner'

interface Member {
  id: string
  name: string
  email: string
  phone: string | null
  member_id: string
  status: 'pending' | 'active' | 'inactive' | 'suspended'
  membership_type: string
  join_date: string
  created_at: string
}

export default function AdminMembers() {
  const { user } = useAuth()
  const [members, setMembers] = useState<Member[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [updating, setUpdating] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadMembers()
  }, [user, searchTerm, statusFilter])

  const loadMembers = async () => {
    try {
      let query = supabase.from('members').select('*')

      // Super admin sees all members, regular admin sees only their association
      if (user?.role !== 'super_admin' && user?.association_id) {
        query = query.eq('association_id', user.association_id)
      }

      if (statusFilter) {
        query = query.eq('status', statusFilter)
      }

      if (searchTerm) {
        query = query.or(`name.ilike.%${searchTerm}%,email.ilike.%${searchTerm}%`)
      }

      const { data, error } = await query.order('created_at', { ascending: false })

      if (error) {
        console.error('Error loading members:', error)
        setError('Failed to load members')
      } else {
        setMembers(data || [])
      }
    } catch (error) {
      console.error('Error loading members:', error)
      setError('Failed to load members')
    } finally {
      setLoading(false)
    }
  }

  const approveMember = async (memberId: string) => {
    setUpdating(memberId)
    setError('')
    setSuccess('')

    try {
      const { error } = await supabase
        .from('members')
        .update({ status: 'active' })
        .eq('id', memberId)

      if (error) {
        setError('Failed to approve member')
      } else {
        setSuccess('Member approved successfully!')
        await loadMembers()
      }
    } catch (error) {
      setError('Failed to approve member')
    } finally {
      setUpdating(null)
    }
  }

  const suspendMember = async (memberId: string) => {
    setUpdating(memberId)
    setError('')
    setSuccess('')

    try {
      const { error } = await supabase
        .from('members')
        .update({ status: 'suspended' })
        .eq('id', memberId)

      if (error) {
        setError('Failed to suspend member')
      } else {
        setSuccess('Member suspended successfully!')
        await loadMembers()
      }
    } catch (error) {
      setError('Failed to suspend member')
    } finally {
      setUpdating(null)
    }
  }

  const getStatusBadge = (status: string) => {
    const statusStyles = {
      active: 'bg-green-100 text-green-800',
      pending: 'bg-yellow-100 text-yellow-800',
      inactive: 'bg-gray-100 text-gray-800',
      suspended: 'bg-red-100 text-red-800'
    }

    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
        statusStyles[status as keyof typeof statusStyles] || statusStyles.inactive
      }`}>
        {status}
      </span>
    )
  }

  const exportMembers = () => {
    const csvContent = [
      ['Name', 'Email', 'Phone', 'Member ID', 'Status', 'Type', 'Join Date'].join(','),
      ...members.map(member => [
        `"${member.name}"`,
        `"${member.email}"`,
        `"${member.phone || ''}"`,
        `"${member.member_id}"`,
        `"${member.status}"`,
        `"${member.membership_type}"`,
        `"${new Date(member.join_date).toLocaleDateString()}"`
      ].join(','))
    ].join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `members-${new Date().toISOString().split('T')[0]}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Member Management</h1>
          <p className="text-gray-600">
            {user?.role === 'super_admin' 
              ? 'Manage all members across associations'
              : 'Manage members in your association'
            }
          </p>
        </div>
        <button
          onClick={exportMembers}
          className="btn-admin flex items-center"
        >
          <Download className="h-4 w-4 mr-2" />
          Export
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

      {/* Filters */}
      <div className="admin-card">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search members..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10 input-field"
              />
            </div>
          </div>
          <div className="sm:w-48">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="input-field"
            >
              <option value="">All Status</option>
              <option value="active">Active</option>
              <option value="pending">Pending</option>
              <option value="inactive">Inactive</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>
        </div>
      </div>

      {/* Members Table */}
      <div className="admin-card">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <LoadingSpinner size="lg" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Member
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Contact
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Join Date
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {members.map((member) => (
                  <tr key={member.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div>
                        <div className="text-sm font-medium text-gray-900">{member.name}</div>
                        <div className="text-sm text-gray-500">ID: {member.member_id}</div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div>
                        <div className="text-sm text-gray-900">{member.email}</div>
                        <div className="text-sm text-gray-500">{member.phone || 'No phone'}</div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getStatusBadge(member.status)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(member.join_date).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <div className="flex items-center space-x-2">
                        {member.status === 'pending' && (
                          <button
                            onClick={() => approveMember(member.id)}
                            disabled={updating === member.id}
                            className="text-green-600 hover:text-green-900 disabled:opacity-50"
                            title="Approve member"
                          >
                            {updating === member.id ? (
                              <LoadingSpinner size="sm" />
                            ) : (
                              <Check className="h-4 w-4" />
                            )}
                          </button>
                        )}
                        
                        {member.status === 'active' && (
                          <button
                            onClick={() => suspendMember(member.id)}
                            disabled={updating === member.id}
                            className="text-red-600 hover:text-red-900 disabled:opacity-50"
                            title="Suspend member"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        )}
                        
                        <button
                          className="text-blue-600 hover:text-blue-900"
                          title="View details"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        
                        <button
                          className="text-gray-600 hover:text-gray-900"
                          title="Edit member"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {members.length === 0 && (
              <div className="text-center py-12">
                <Users className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No members found</h3>
                <p className="mt-1 text-sm text-gray-500">
                  {searchTerm || statusFilter 
                    ? 'Try adjusting your search or filter criteria.'
                    : 'No members have joined yet.'
                  }
                </p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}