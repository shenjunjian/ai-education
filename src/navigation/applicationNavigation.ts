export type LearningMode = 'english' | 'math'
export type VisibleLayer = 'shell' | LearningMode

export type ApplicationNavigation = {
  getVisibleLayer: () => VisibleLayer
  isLayerVisible: (layer: VisibleLayer) => boolean
  enter: (mode: LearningMode) => void
  exit: () => void
  subscribe: (listener: (layer: VisibleLayer) => void) => () => void
}

export function createApplicationNavigation(): ApplicationNavigation {
  let visibleLayer: VisibleLayer = 'shell'
  const listeners = new Set<(layer: VisibleLayer) => void>()

  function notify() {
    for (const listener of listeners) {
      listener(visibleLayer)
    }
  }

  return {
    getVisibleLayer() {
      return visibleLayer
    },
    isLayerVisible(layer) {
      return visibleLayer === layer
    },
    enter(mode) {
      visibleLayer = mode
      notify()
    },
    exit() {
      visibleLayer = 'shell'
      notify()
    },
    subscribe(listener) {
      listeners.add(listener)
      return () => {
        listeners.delete(listener)
      }
    },
  }
}
