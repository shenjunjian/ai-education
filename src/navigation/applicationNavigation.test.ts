import { describe, expect, test } from 'vitest'
import { createApplicationNavigation } from './applicationNavigation'

describe('应用导航', () => {
  test('打开时可见层为外壳', () => {
    const nav = createApplicationNavigation()

    expect(nav.getVisibleLayer()).toBe('shell')
    expect(nav.isLayerVisible('shell')).toBe(true)
    expect(nav.isLayerVisible('english')).toBe(false)
    expect(nav.isLayerVisible('math')).toBe(false)
  })

  test('进入英语学习模式后仅英语主界面可见', () => {
    const nav = createApplicationNavigation()

    nav.enter('english')

    expect(nav.getVisibleLayer()).toBe('english')
    expect(nav.isLayerVisible('english')).toBe(true)
    expect(nav.isLayerVisible('math')).toBe(false)
    expect(nav.isLayerVisible('shell')).toBe(false)
  })

  test('进入数学学习模式后仅数学主界面可见', () => {
    const nav = createApplicationNavigation()

    nav.enter('math')

    expect(nav.getVisibleLayer()).toBe('math')
    expect(nav.isLayerVisible('math')).toBe(true)
    expect(nav.isLayerVisible('english')).toBe(false)
    expect(nav.isLayerVisible('shell')).toBe(false)
  })

  test('从英语学习模式退出回到外壳', () => {
    const nav = createApplicationNavigation()
    nav.enter('english')

    nav.exit()

    expect(nav.getVisibleLayer()).toBe('shell')
    expect(nav.isLayerVisible('english')).toBe(false)
  })

  test('从数学学习模式退出回到外壳', () => {
    const nav = createApplicationNavigation()
    nav.enter('math')

    nav.exit()

    expect(nav.getVisibleLayer()).toBe('shell')
    expect(nav.isLayerVisible('math')).toBe(false)
  })

  test('切换学习模式须经外壳：退出后再进入另一模式', () => {
    const nav = createApplicationNavigation()
    nav.enter('english')
    nav.exit()
    nav.enter('math')

    expect(nav.getVisibleLayer()).toBe('math')
    expect(nav.isLayerVisible('english')).toBe(false)
  })
})
