/**
 * PocketBase JavaScript SDK
 * https://github.com/pocketbase/js-sdk
 */

;(function(global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
    typeof define === 'function' && define.amd ? define(['exports'], factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.PocketBase = {}));
}(this, (function(exports) {
    'use strict';

    // Simplified PocketBase client for demo purposes
    // In production, use the official PocketBase JavaScript SDK

    class PocketBase {
        constructor(baseUrl = window.location.origin) {
            this.baseUrl = baseUrl.replace(/\/+$/, '');
            this.authStore = new AuthStore();
        }

        collection(name) {
            return new RecordService(this, name);
        }

        async send(path, options = {}) {
            const url = this.baseUrl + '/api/' + path.replace(/^\//, '');
            
            const headers = {
                'Content-Type': 'application/json',
                ...options.headers
            };

            if (this.authStore.token) {
                headers['Authorization'] = `Bearer ${this.authStore.token}`;
            }

            const config = {
                method: options.method || 'GET',
                headers,
                ...options
            };

            if (options.body && typeof options.body === 'object') {
                config.body = JSON.stringify(options.body);
            }

            const response = await fetch(url, config);
            
            if (!response.ok) {
                const error = await response.text();
                throw new Error(error || `HTTP ${response.status}`);
            }

            return await response.json();
        }
    }

    class AuthStore {
        constructor() {
            this.token = localStorage.getItem('pocketbase_auth_token') || '';
            this.model = JSON.parse(localStorage.getItem('pocketbase_auth_model') || 'null');
            this.onChange = () => {};
        }

        get isValid() {
            return !!(this.token && this.model);
        }

        save(token, model) {
            this.token = token;
            this.model = model;
            
            localStorage.setItem('pocketbase_auth_token', token);
            localStorage.setItem('pocketbase_auth_model', JSON.stringify(model));
            
            this.onChange(token, model);
        }

        clear() {
            this.token = '';
            this.model = null;
            
            localStorage.removeItem('pocketbase_auth_token');
            localStorage.removeItem('pocketbase_auth_model');
            
            this.onChange('', null);
        }
    }

    class RecordService {
        constructor(client, collection) {
            this.client = client;
            this.collection = collection;
        }

        async getFullList(batch = 200, options = {}) {
            return await this.client.send(`collections/${this.collection}/records`, {
                method: 'GET',
                ...options
            });
        }

        async getList(page = 1, perPage = 30, options = {}) {
            const params = new URLSearchParams({
                page: page.toString(),
                perPage: perPage.toString(),
                ...options.params
            });

            if (options.filter) params.set('filter', options.filter);
            if (options.sort) params.set('sort', options.sort);

            return await this.client.send(`collections/${this.collection}/records?${params}`);
        }

        async getOne(id, options = {}) {
            return await this.client.send(`collections/${this.collection}/records/${id}`, {
                method: 'GET',
                ...options
            });
        }

        async getFirstListItem(filter, options = {}) {
            const result = await this.getList(1, 1, { ...options, filter });
            if (!result.items || result.items.length === 0) {
                throw new Error('No records found');
            }
            return result.items[0];
        }

        async create(data, options = {}) {
            return await this.client.send(`collections/${this.collection}/records`, {
                method: 'POST',
                body: data,
                ...options
            });
        }

        async update(id, data, options = {}) {
            return await this.client.send(`collections/${this.collection}/records/${id}`, {
                method: 'PATCH',
                body: data,
                ...options
            });
        }

        async delete(id, options = {}) {
            return await this.client.send(`collections/${this.collection}/records/${id}`, {
                method: 'DELETE',
                ...options
            });
        }

        async authWithPassword(identity, password, options = {}) {
            const result = await this.client.send(`collections/${this.collection}/auth-with-password`, {
                method: 'POST',
                body: { identity, password },
                ...options
            });

            this.client.authStore.save(result.token, result.record);
            return result;
        }
    }

    // Export classes
    exports.PocketBase = PocketBase;
    exports.AuthStore = AuthStore;
    exports.RecordService = RecordService;

})));

// Global PocketBase instance
if (typeof window !== 'undefined') {
    window.PocketBase = exports.PocketBase;
}