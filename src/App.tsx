import React from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './contexts/AuthContext'
import Layout from './components/Layout'
import AdminLayout from './components/AdminLayout'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import DashboardPage from './pages/DashboardPage'
import MembersPage from './pages/MembersPage'
import ProfilePage from './pages/ProfilePage'
import MailingListsPage from './pages/MailingListsPage'
import EmailCampaignsPage from './pages/EmailCampaignsPage'
import AdminDashboard from './pages/admin/AdminDashboard'
import AdminMembers from './pages/admin/AdminMembers'
import AdminMailingLists from './pages/admin/AdminMailingLists'
import AdminEmailCampaigns from './pages/admin/AdminEmailCampaigns'
import AdminSettings from './pages/admin/AdminSettings'
import LoadingSpinner from './components/LoadingSpinner'

function App() {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  // Check if this is admin domain
  const isAdminDomain = window.location.hostname.includes('p.') || 
                       window.location.pathname.startsWith('/admin')

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    )
  }

  // Admin routes
  if (isAdminDomain || user.role === 'admin' || user.role === 'super_admin') {
    return (
      <AdminLayout>
        <Routes>
          <Route path="/" element={<AdminDashboard />} />
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/admin/dashboard" element={<AdminDashboard />} />
          <Route path="/admin/members" element={<AdminMembers />} />
          <Route path="/admin/mailing-lists" element={<AdminMailingLists />} />
          <Route path="/admin/email-campaigns" element={<AdminEmailCampaigns />} />
          <Route path="/admin/settings" element={<AdminSettings />} />
          <Route path="*" element={<Navigate to="/admin/dashboard" replace />} />
        </Routes>
      </AdminLayout>
    )
  }

  // Member routes
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/members" element={<MembersPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/mailing-lists" element={<MailingListsPage />} />
        <Route path="/email-campaigns" element={<EmailCampaignsPage />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </Layout>
  )
}

export default App