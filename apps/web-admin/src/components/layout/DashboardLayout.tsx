"use client";

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Button } from '@/components/ui/button'

const navItems = [
  { href: '/dashboard', label: 'Дашборд', icon: '📊' },
  { href: '/create-gig', label: 'Создать смену', icon: '➕' },
  { href: '/my-gigs', label: 'Мои смены', icon: '📅' },
  { href: '/objects', label: 'Мои объекты', icon: '🏢' },
  { href: '/balance', label: 'Баланс', icon: '💰' },
  { href: '/promotions', label: 'Акции', icon: '🎁' },
  { href: '/stats', label: 'Статистика', icon: '📈' },
  { href: '/profile', label: 'Профиль', icon: '👤' },
]

export function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="fixed left-0 top-0 h-full w-64 border-r bg-white">
        <div className="p-6">
          <h1 className="text-2xl font-bold text-blue-600">Smenube.ru</h1>
          <p className="text-sm text-gray-500 mt-1">Кабинет заказчика</p>
        </div>
        
        <nav className="mt-8 px-4">
          {navItems.map((item) => {
            const isActive = pathname === item.href
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-4 py-3 rounded-lg mb-1 transition ${
                  isActive
                    ? 'bg-blue-50 text-blue-600 font-medium'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <span className="text-lg">{item.icon}</span>
                <span>{item.label}</span>
              </Link>
            )
          })}
        </nav>

        <div className="absolute bottom-0 left-0 right-0 p-4 border-t">
          <div className="text-sm text-gray-500">© Smenube.ru 2024</div>
        </div>
      </aside>

      {/* Main content */}
      <main className="ml-64 p-8">
        <div className="max-w-6xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  )
}
