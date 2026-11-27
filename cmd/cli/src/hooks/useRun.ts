import { useEffect, useReducer } from 'react';
import type { CliArgs } from '../config/args';
import { initialState, reduce, type RunState } from '../domain/state';
import { startRun } from '../infra/runner';

/** Runs the Go core once and exposes its progress as React state. */
export function useRun(args: CliArgs): RunState {
  const [state, dispatch] = useReducer(reduce, undefined, () => initialState(Date.now()));
  useEffect(() => {
    const handle = startRun(args, dispatch);
    return () => handle.stop();
  }, [args]);
  return state;
}
