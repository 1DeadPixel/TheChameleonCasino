import Image from 'next/image'

export default function Home() {
  return (
    <main className="flex min-h-screen h-screen flex-col">
      <header className="z-10 p-6 max-w-5xl mx-auto flex w-full items-center justify-between font-mono text-sm lg:flex">
        <div>The Chameleon Casino</div>
        <button className="border p-2">Launch App</button>
      </header>
      <main className="flex h-full justify-between  relative my-14 gap-14">
        <div className="flex flex-col flex-1 gap-4 items-end justify-center">
          <h1 className="text-3xl">Welcome!</h1>
          <h2 className="text-4xl">
            <span className="text-xl">to the</span> Chameleon Casino
          </h2>
        </div>
        {/* <div className="bg-landing bg-cover shadow-inner bg-no-repeat h-[500px] w-full"></div> */}
        <div className="flex-1 relative">
          <Image alt="" fill src="/Landing.png" className="max-h-[500px]" />
        </div>
      </main>

      <footer className="max-w-5xl w-full mx-auto flex justify-between">
        <div className="flex justify-between flex-row lg:flex-col mb-10 lg:mb-0">
          {/* <Image alt="pulsar-data-logo" src="/logo.svg" width={132} height={24} /> */}

          <p className="text-text-secondary text-sm">@ 2023, Chameleon Casino</p>
        </div>

        <div className="grid grid-cols-2 lg:grid-cols-2 gap-x-16 gap-y-10">
          <ul className="flex flex-col gap-8">
            <h2 className="text-text text-sm font-semibold">Resources</h2>

            <li>
              <a
                target="_blank"
                rel="nofollow noopener noreferrer"
                className="text-text-secondary text-sm cursor-pointer hover:text-text"
              >
                Documentation
              </a>
            </li>
          </ul>

          <ul className="flex flex-col gap-8">
            <h2 className="text-text text-sm font-semibold">Socials</h2>

            <li>
              <a
                target="_blank"
                rel="nofollow noopener noreferrer"
                className="text-text-secondary text-sm cursor-pointer hover:text-text"
              >
                Twitter
              </a>
            </li>
            <li>
              <a
                target="_blank"
                rel="nofollow noopener noreferrer"
                className="text-text-secondary text-sm cursor-pointer hover:text-text"
              >
                Telegram
              </a>
            </li>
          </ul>
        </div>
      </footer>
    </main>
  )
}
