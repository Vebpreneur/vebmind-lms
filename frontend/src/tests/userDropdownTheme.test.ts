/** Dark-only LMS must not offer an appearance switch in the user menu. */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// Only what this suite controls is replaced; the rest of frappe-ui stays real.
// Dropdown becomes a prop-capturing stub because the assertions are about the
// menu's own data (which rows exist, what they call), not popover mechanics.
vi.mock('frappe-ui', async () => {
	const actual = await vi.importActual<typeof import('frappe-ui')>('frappe-ui')
	return {
		...actual,
		call: vi.fn(),
		createResource: () => ({ data: null, loading: false, submit: vi.fn() }),
		toast: { success: vi.fn(), error: vi.fn() },
		Dropdown: {
			name: 'Dropdown',
			props: ['options'],
			template: `<div><slot :open="false" :close="() => {}" /></div>`,
		},
	}
})

vi.mock('@/stores/session', () => ({
	sessionStore: () => ({
		logout: { submit: vi.fn() },
		branding: { data: null },
		isLoggedIn: true,
	}),
}))

vi.mock('@/stores/user', () => ({
	usersStore: () => ({ userResource: { data: { is_moderator: false } } }),
}))

vi.mock('@/stores/settings', () => ({
	useSettings: () => ({ settings: { data: null } }),
}))

vi.mock('@/composables/useSettingsHash', () => ({ pushSettingsHash: vi.fn() }))
vi.mock('@/utils/openExternal', () => ({ openExternal: vi.fn() }))
vi.mock('@/utils/dialogs', () => ({ createDialog: vi.fn() }))
vi.mock('@/components/Icons/LMSLogo.vue', () => ({
	default: { template: '<div />' },
}))
vi.mock('@/components/Settings/Settings.vue', () => ({
	default: { template: '<div />' },
}))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('@/utils', () => ({ convertToTitleCase: (s: string) => s }))
vi.mock('@/utils/safeUrl', () => ({ safeUrl: (s: string) => s }))

vi.stubGlobal('__', (text: string) => text)

import UserDropdown from '@/components/Sidebar/UserDropdown.vue'
import { setThemePreference, themePreference } from '@/utils/theme'

function build() {
	setActivePinia(createPinia())
	return mount(UserDropdown, { global: { mocks: { __: (t: string) => t } } })
}

describe('UserDropdown dark-only menu', () => {
	it('does not expose a theme selector', () => {
		setThemePreference('light')
		expect(themePreference.value).toBe('dark')
		const options = build().findComponent({ name: 'Dropdown' }).props('options')
		const labels = options.flatMap((group: any) => group.options.map((item: any) => item.label))
		expect(labels).not.toContain('Theme')
	})
})
