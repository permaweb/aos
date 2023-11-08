// import * as R from 'ramda'


// export const path = R.path
// export const identity = R.identity

export const path = props => obj => props.reduce((acc, key) => (acc && acc[key] !== undefined) ? acc[key] : undefined, obj)
export const identity = x => x
