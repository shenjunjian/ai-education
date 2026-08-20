import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'
import { createApplicationNavigation } from './navigation/applicationNavigation'
import './index.css'

const navigation = createApplicationNavigation()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App navigation={navigation} />
  </StrictMode>,
)
