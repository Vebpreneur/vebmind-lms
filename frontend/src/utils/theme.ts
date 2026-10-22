import { ref } from 'vue'

// This distribution has one supported appearance: dark.
// Keep the public exports for consumers that already import them, but never
// allow an older light/system preference or OS setting to change the UI.
export type Theme = 'light' | 'dark'
export type ThemePreference = Theme | 'system'

const theme = ref<Theme>('dark')
const themePreference = ref<ThemePreference>('dark')

const paintDark = (): void => {
	if (typeof document !== 'undefined') {
		document.documentElement.setAttribute('data-theme', 'dark')
	}
	try {
		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('theme', 'dark')
			localStorage.setItem('themePreference', 'dark')
		}
	} catch {
		// Storage may be blocked in private browsing; the document stays dark.
	}
	theme.value = 'dark'
	themePreference.value = 'dark'
}

// A compatibility no-op for existing importers: any requested mode resolves
// to dark, including explicit calls with light or system.
const setThemePreference = (_preference: ThemePreference): void => {
	paintDark()
}

paintDark()

export { setThemePreference, theme, themePreference }
