import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, test } from 'vitest'
import { App } from './App'
import { createApplicationNavigation } from './navigation/applicationNavigation'

describe('应用外壳与学习模式进出', () => {
  test('打开应用见外壳左右分区（英语 | 数学）', () => {
    render(<App navigation={createApplicationNavigation()} />)

    expect(screen.getByRole('main', { name: '外壳' })).toBeTruthy()
    expect(screen.getByRole('button', { name: '英语' })).toBeTruthy()
    expect(screen.getByRole('button', { name: '数学' })).toBeTruthy()
  })

  test('点选英语进入英语学习模式，数学主界面不可见，可退出回外壳', async () => {
    const user = userEvent.setup()
    render(<App navigation={createApplicationNavigation()} />)

    await user.click(screen.getByRole('button', { name: '英语' }))

    expect(screen.getByRole('main', { name: '英语学习模式' })).toBeTruthy()
    expect(screen.queryByRole('main', { name: '数学学习模式' })).toBeNull()
    expect(screen.queryByRole('main', { name: '外壳' })).toBeNull()

    await user.click(screen.getByRole('button', { name: '退出' }))

    expect(screen.getByRole('main', { name: '外壳' })).toBeTruthy()
  })

  test('点选数学进入数学学习模式，英语主界面不可见，可退出回外壳', async () => {
    const user = userEvent.setup()
    render(<App navigation={createApplicationNavigation()} />)

    await user.click(screen.getByRole('button', { name: '数学' }))

    expect(screen.getByRole('main', { name: '数学学习模式' })).toBeTruthy()
    expect(screen.queryByRole('main', { name: '英语学习模式' })).toBeNull()
    expect(screen.queryByRole('main', { name: '外壳' })).toBeNull()

    await user.click(screen.getByRole('button', { name: '退出' }))

    expect(screen.getByRole('main', { name: '外壳' })).toBeTruthy()
  })
})
