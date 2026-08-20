import { useEffect, useState } from 'react'
import type {
  ApplicationNavigation,
  LearningMode,
  VisibleLayer,
} from './navigation/applicationNavigation'

type AppProps = {
  navigation: ApplicationNavigation
}

export function App({ navigation }: AppProps) {
  const [visibleLayer, setVisibleLayer] = useState<VisibleLayer>(() =>
    navigation.getVisibleLayer(),
  )

  useEffect(() => navigation.subscribe(setVisibleLayer), [navigation])

  if (visibleLayer === 'english') {
    return (
      <LearningModePlaceholder
        mode="english"
        label="英语学习模式"
        onExit={() => navigation.exit()}
      />
    )
  }

  if (visibleLayer === 'math') {
    return (
      <LearningModePlaceholder
        mode="math"
        label="数学学习模式"
        onExit={() => navigation.exit()}
      />
    )
  }

  return <Shell onEnter={(mode) => navigation.enter(mode)} />
}

type ShellProps = {
  onEnter: (mode: LearningMode) => void
}

function Shell({ onEnter }: ShellProps) {
  return (
    <main className="shell" aria-label="外壳">
      <button
        type="button"
        className="shell-panel shell-panel-english"
        onClick={() => onEnter('english')}
      >
        英语
      </button>
      <button
        type="button"
        className="shell-panel shell-panel-math"
        onClick={() => onEnter('math')}
      >
        数学
      </button>
    </main>
  )
}

type LearningModePlaceholderProps = {
  mode: LearningMode
  label: string
  onExit: () => void
}

function LearningModePlaceholder({
  mode,
  label,
  onExit,
}: LearningModePlaceholderProps) {
  return (
    <main className="learning-mode" aria-label={label} data-mode={mode}>
      <h1>{label}</h1>
      <button type="button" onClick={onExit}>
        退出
      </button>
    </main>
  )
}
