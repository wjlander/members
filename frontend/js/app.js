// PocketBase client configuration
const pb = new PocketBase(window.location.origin);

function app() {
    return {
        // State management
        loading: false,
        error: '',
        success: '',
        currentUser: null,
        currentView: 'members', // members, profile, dues, settings, reports
        
        // Association management
        associations: [],
        selectedAssociation: null,
        currentAssociation: null,
        
        // Forms
        loginForm: {
            email: '',
            password: ''
        },
        registerForm: {
            name: '',
            email: '',
            phone: '',
            password: '',
            confirmPassword: ''
        },
        profileForm: {
            name: '',
            email: '',
            phone: '',
            address: '',
            member_id: '',
            status: ''
        },
        
        // UI state
        showRegisterForm: false,
        
        // Data
        members: [],
        memberFilter: {
            status: '',
            search: ''
        },
        memberDues: {
            outstanding: 0,
            payments: []
        },
        reports: {
            totalMembers: 0,
            activeMembers: 0,
            pendingMembers: 0,
            monthlyRevenue: 0,
            recentActivity: []
        },

        // Initialize the app
        async init() {
            try {
                // Load associations
                await this.loadAssociations();
                
                // Check for existing authentication
                if (pb.authStore.isValid) {
                    this.currentUser = pb.authStore.model;
                    await this.loadUserData();
                }
                
                // Setup automatic token refresh
                pb.authStore.onChange((token, model) => {
                    this.currentUser = model;
                    if (model) {
                        this.loadUserData();
                    }
                });
                
                // Auto-clear messages
                setInterval(() => {
                    if (this.error) this.error = '';
                    if (this.success) this.success = '';
                }, 5000);
                
            } catch (error) {
                console.error('Initialization error:', error);
                this.showError('Failed to initialize application');
            }
        },

        // Load associations
        async loadAssociations() {
            try {
                const result = await pb.collection('organizations').getFullList();
                this.associations = result;
            } catch (error) {
                console.error('Failed to load associations:', error);
                this.showError('Failed to load associations');
            }
        },

        // Select association
        selectAssociation(association) {
            this.selectedAssociation = association;
            this.currentAssociation = association;
            this.loginForm.email = '';
            this.loginForm.password = '';
        },

        // Authentication
        async login() {
            if (!this.selectedAssociation) {
                this.showError('Please select an association first');
                return;
            }

            this.loading = true;
            try {
                const authData = await pb.collection('app_users').authWithPassword(
                    this.loginForm.email,
                    this.loginForm.password
                );

                // Verify user belongs to selected association
                const member = await this.getMemberByUserId(authData.record.id);
                if (!member || member.association !== this.selectedAssociation.id) {
                    throw new Error('Invalid association for this user');
                }

                this.currentUser = authData.record;
                this.currentUser.role = member.role || 'member';
                this.currentAssociation = this.selectedAssociation;
                
                await this.loadUserData();
                this.showSuccess('Login successful!');
                
            } catch (error) {
                console.error('Login error:', error);
                this.showError(error.message || 'Login failed. Please check your credentials.');
            } finally {
                this.loading = false;
            }
        },

        // Registration
        async register() {
            if (this.registerForm.password !== this.registerForm.confirmPassword) {
                this.showError('Passwords do not match');
                return;
            }

            this.loading = true;
            try {
                // Create user account
                const userData = {
                    email: this.registerForm.email,
                    password: this.registerForm.password,
                    passwordConfirm: this.registerForm.confirmPassword,
                    name: this.registerForm.name
                };

                const user = await pb.collection('app_users').create(userData);

                // Create member record
                const memberData = {
                    user: user.id,
                    association: this.selectedAssociation.id,
                    name: this.registerForm.name,
                    email: this.registerForm.email,
                    phone: this.registerForm.phone,
                    member_id: await this.generateMemberId(),
                    status: 'pending',
                    role: 'member'
                };

                await pb.collection('org_members').create(memberData);

                this.showSuccess('Registration successful! Your account is pending approval.');
                this.showRegisterForm = false;
                this.resetRegisterForm();
                
            } catch (error) {
                console.error('Registration error:', error);
                this.showError(error.message || 'Registration failed. Please try again.');
            } finally {
                this.loading = false;
            }
        },

        // Logout
        async logout() {
            pb.authStore.clear();
            this.currentUser = null;
            this.selectedAssociation = null;
            this.currentAssociation = null;
            this.currentView = 'members';
            this.resetForms();
        },

        // Load user-specific data
        async loadUserData() {
            if (!this.currentUser) return;

            try {
                const member = await this.getMemberByUserId(this.currentUser.id);
                if (member) {
                    this.profileForm = { ...member };
                    this.currentAssociation = this.associations.find(a => a.id === member.association);
                }

                // Load appropriate data based on role
                if (this.currentUser.role === 'admin') {
                    await this.loadMembers();
                    await this.loadReports();
                } else {
                    await this.loadMemberDues();
                }
                
            } catch (error) {
                console.error('Failed to load user data:', error);
            }
        },

        // Get member by user ID
        async getMemberByUserId(userId) {
            try {
                const result = await pb.collection('org_members').getFirstListItem(`user="${userId}"`);
                return result;
            } catch (error) {
                return null;
            }
        },

        // Profile management
        async updateProfile() {
            this.loading = true;
            try {
                await pb.collection('org_members').update(this.profileForm.id, {
                    name: this.profileForm.name,
                    email: this.profileForm.email,
                    phone: this.profileForm.phone,
                    address: this.profileForm.address
                });

                // Also update user record if email changed
                if (this.profileForm.email !== this.currentUser.email) {
                    await pb.collection('app_users').update(this.currentUser.id, {
                        email: this.profileForm.email
                    });
                }

                this.showSuccess('Profile updated successfully!');
            } catch (error) {
                console.error('Profile update error:', error);
                this.showError('Failed to update profile');
            } finally {
                this.loading = false;
            }
        },

        // Member management (Admin)
        async loadMembers() {
            if (!this.currentAssociation) return;

            try {
                let filter = `association="${this.currentAssociation.id}"`;
                
                if (this.memberFilter.status) {
                    filter += ` && status="${this.memberFilter.status}"`;
                }
                
                if (this.memberFilter.search) {
                    filter += ` && (name~"${this.memberFilter.search}" || email~"${this.memberFilter.search}")`;
                }

                const result = await pb.collection('org_members').getList(1, 50, {
                    filter: filter,
                    sort: '-created'
                });
                
                this.members = result.items;
            } catch (error) {
                console.error('Failed to load members:', error);
                this.showError('Failed to load members');
            }
        },

        // Approve member
        async approveMember(member) {
            try {
                await pb.collection('org_members').update(member.id, {
                    status: 'active'
                });
                
                // Send welcome email (if email service is configured)
                // await this.sendWelcomeEmail(member);
                
                this.showSuccess(`${member.name} has been approved!`);
                await this.loadMembers();
                
            } catch (error) {
                console.error('Failed to approve member:', error);
                this.showError('Failed to approve member');
            }
        },

        // Load member dues
        async loadMemberDues() {
            try {
                const member = await this.getMemberByUserId(this.currentUser.id);
                if (!member) return;

                // Load dues information
                const duesResult = await pb.collection('org_dues').getList(1, 50, {
                    filter: `member="${member.id}"`,
                    sort: '-created'
                });

                let outstanding = 0;
                const payments = [];

                for (const due of duesResult.items) {
                    if (due.status !== 'paid') {
                        outstanding += due.amount;
                    }
                    payments.push(due);
                }

                this.memberDues = {
                    outstanding,
                    payments
                };
                
            } catch (error) {
                console.error('Failed to load dues:', error);
            }
        },

        // Load reports (Admin)
        async loadReports() {
            if (!this.currentAssociation) return;

            try {
                // Get member statistics
                const allMembers = await pb.collection('org_members').getList(1, 1000, {
                    filter: `association="${this.currentAssociation.id}"`
                });

                const totalMembers = allMembers.items.length;
                const activeMembers = allMembers.items.filter(m => m.status === 'active').length;
                const pendingMembers = allMembers.items.filter(m => m.status === 'pending').length;

                // Calculate monthly revenue (simplified)
                const currentMonth = new Date().getMonth() + 1;
                const currentYear = new Date().getFullYear();
                
                const monthlyDues = await pb.collection('org_dues').getList(1, 1000, {
                    filter: `created >= "${currentYear}-${currentMonth.toString().padStart(2, '0')}-01" && status="paid"`
                });

                const monthlyRevenue = monthlyDues.items.reduce((sum, due) => sum + due.amount, 0);

                // Recent activity (simplified)
                const recentActivity = [
                    {
                        id: 1,
                        description: `${pendingMembers} members pending approval`,
                        timestamp: 'Today',
                        icon: 'fas fa-user-clock'
                    },
                    {
                        id: 2,
                        description: `$${monthlyRevenue} collected this month`,
                        timestamp: 'This month',
                        icon: 'fas fa-dollar-sign'
                    }
                ];

                this.reports = {
                    totalMembers,
                    activeMembers,
                    pendingMembers,
                    monthlyRevenue,
                    recentActivity
                };

            } catch (error) {
                console.error('Failed to load reports:', error);
            }
        },

        // Export members
        async exportMembers() {
            try {
                const allMembers = await pb.collection('org_members').getList(1, 1000, {
                    filter: `association="${this.currentAssociation.id}"`
                });

                // Convert to CSV
                const headers = ['Name', 'Email', 'Phone', 'Member ID', 'Status', 'Joined'];
                const csvContent = [
                    headers.join(','),
                    ...allMembers.items.map(member => [
                        `"${member.name}"`,
                        `"${member.email}"`,
                        `"${member.phone || ''}"`,
                        `"${member.member_id}"`,
                        `"${member.status}"`,
                        `"${new Date(member.created).toLocaleDateString()}"`
                    ].join(','))
                ].join('\n');

                // Download file
                const blob = new Blob([csvContent], { type: 'text/csv' });
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `${this.currentAssociation.name}-members-${new Date().toISOString().split('T')[0]}.csv`;
                a.click();
                window.URL.revokeObjectURL(url);

                this.showSuccess('Members list exported successfully!');
                
            } catch (error) {
                console.error('Export failed:', error);
                this.showError('Failed to export members');
            }
        },

        // Utility functions
        async generateMemberId() {
            const prefix = this.selectedAssociation.code || 'MEM';
            const timestamp = Date.now().toString().slice(-6);
            return `${prefix}${timestamp}`;
        },

        debounceSearch() {
            clearTimeout(this.searchTimeout);
            this.searchTimeout = setTimeout(() => {
                this.loadMembers();
            }, 300);
        },

        resetForms() {
            this.loginForm = { email: '', password: '' };
            this.resetRegisterForm();
        },

        resetRegisterForm() {
            this.registerForm = {
                name: '',
                email: '',
                phone: '',
                password: '',
                confirmPassword: ''
            };
        },

        showError(message) {
            this.error = message;
            setTimeout(() => this.error = '', 5000);
        },

        showSuccess(message) {
            this.success = message;
            setTimeout(() => this.success = '', 5000);
        },

        // Member actions (Admin)
        viewMember(member) {
            // Implement member detail view
            console.log('View member:', member);
        },

        editMember(member) {
            // Implement member edit functionality
            console.log('Edit member:', member);
        },

        // Mailing list actions (Admin)
        editMailingList(mailingList) {
            // Implement mailing list edit functionality
            console.log('Edit mailing list:', mailingList);
        },

        viewSubscribers(mailingList) {
            // Implement subscriber view functionality
            console.log('View subscribers for:', mailingList);
        }
    };
}