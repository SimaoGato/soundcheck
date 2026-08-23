import { render, screen } from '@testing-library/react-native';
import App from './App';

test('renders the app name and a start affordance', async () => {
  await render(<App />);
  expect(screen.getByText(/soundcheck/i)).toBeTruthy();
  expect(screen.getByRole('button', { name: /start/i })).toBeTruthy();
});
