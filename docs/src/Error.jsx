export default function Error({ error }) {
    return <div>
        <h2>{error?.name}</h2>
        <p>{error?.documentation?.text}</p>
        <code>{error?.errorSelector}</code>
    </div>
}