import { inputMethod } from '@kit.IMEKit'
import { Callback, getStreamAI } from '../utlis/StreamAIUtil'
import { Header } from '../components/Header';

const TAG = 'Home';
const DOMAIN = 0x0001;

@Entry
@Component
struct Home {
  // 输入的问题
  @State question: string = ''
  // 我发出的消息
  @State myMsgArr: string[] = []
  // 滚动控制器
  private scrollerForScroll: Scroller = new Scroller()
  // 回答原因
  @State reasonContent: string[] = []
  @State reason: string = ''
  // 回答结果
  @State content: string[] = []
  @State con: string = ''
  // 第几段问答
  @State num: number = 0
  // 是否正在思考（用于UI显示）
  @State isThinking: boolean[] = []
  @State isSending: boolean = false

  private updateReasonAt(index: number, text: string): void {
    const arr = [...this.reasonContent]
    arr[index] = text
    this.reasonContent = arr
  }

  private updateContentAt(index: number, text: string): void {
    const arr = [...this.content]
    arr[index] = text
    this.content = arr
  }

  private updateThinkingAt(index: number, thinking: boolean): void {
    const arr = [...this.isThinking]
    arr[index] = thinking
    this.isThinking = arr
  }

  onPageShow() {
    this.question = ''
    this.myMsgArr = []
    this.reasonContent = []
    this.content = []
    this.isThinking = []
    this.reason = ''
    this.con = ''
    this.num = 0
    this.isSending = false
  }

  build() {
    Column() {
      // 右侧区域
      Column() {
        Header({
          title: 'AI大模型',
          onClickF: () => {}
        })
        // 聊天显示区域
        Scroll(this.scrollerForScroll) {
          Column({ space: 10 }) {
            ForEach(this.myMsgArr, (value: string, index: number) => {
              // 用户
              Flex({ direction: FlexDirection.Row }) {
                Image($r('app.media.user'))
                  .width(40)
                Text(value)
                  .fontSize(16)
                  .fontColor(Color.White)
                  .backgroundColor('#81BCFF')
                  .padding(10)
                  .margin({ right: 10, left: 50 })
                  .borderRadius(10)
              }.width('100%')
              .direction(Direction.Rtl)

              // AI
              Flex({ direction: FlexDirection.Row }) {
                Image($r('app.media.rebot'))
                  .width(40)
                Column() {
                  if (this.isThinking[index]) {
                    Text('正在回复中...').fontSize(14).fontColor('#666')
                  }

                  if ((this.reasonContent[index] || '').length > 0) {
                    Column({ space: 6 }) {
                      Text('思考过程').fontSize(14).fontColor('#666')
                      Text(this.reasonContent[index])
                        .fontSize(14)
                        .fontColor(Color.Gray)
                    }
                    .width('100%')
                    .backgroundColor('#E2F0FF')
                    .padding(10)
                    .border({ width: 1, color: '#81BCFF', radius: 10 })
                    .alignItems(HorizontalAlign.Start)
                    .margin({ bottom: 8 })
                  }

                  // 【修改】恢复纯文本显示，移除 MarkdownWebView 组件
                  if ((this.content[index] || '').length > 0) {
                    Text(this.content[index])
                      .fontSize(16)
                      .fontColor('#333')
                      .width('100%')
                      .textAlign(TextAlign.Start)
                      .lineHeight(24)
                  } else if (!this.isThinking[index]) {
                    Text('暂无回复内容')
                      .fontSize(16)
                      .fontColor('#999')
                      .width('100%')
                      .textAlign(TextAlign.Start)
                  }
                }
                .margin({ left: 10, right: 10 })
                .alignItems(HorizontalAlign.Start)
              }.width('100%')
              .direction(Direction.Ltr)
            }, (value: string, index: number) => `${index}_${value}`)
          }.width('100%')
        }.layoutWeight(1)
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        // 问题输入框
        Row({ space: 10 }) {
          TextInput({ placeholder: '请输入想问的问题', text: this.question })
            .onChange((value: string) => this.question = value)
            .height('100%')
            .fontSize(16)
            .layoutWeight(1)
            .border({ width: 2, color: '#81BCFF'})
            .backgroundColor('#E2F0FF')
            .borderRadius(10)


          Button(this.isSending ? '发送中' : '发送', { type: ButtonType.Normal })
            .border({ radius: 10 })
            .height('100%')
            .fontSize(16)
            .backgroundColor('#81BCFF')
            .enabled(!this.isSending)
            .onClick(async () => {
              const question = this.question.trim()
              if (question.length === 0 || this.isSending) {
                return
              }

              this.isSending = true
              this.reason = ''
              this.con = ''
              const currentIndex = this.num
              this.question = ''
              inputMethod.getController().stopInputSession();

              this.myMsgArr = [...this.myMsgArr, question]
              this.reasonContent = [...this.reasonContent, '']
              this.content = [...this.content, '']
              this.isThinking = [...this.isThinking, true]

              const callback: Callback = {
                onError: (error: Error) => {
                  console.error('请求错误', error)
                  this.updateThinkingAt(currentIndex, false)
                  this.updateContentAt(currentIndex, `请求失败：${error.message}`)
                  this.isSending = false
                },
                onDataReceive: (reasonContent: string, replyContent: string) => {
                  if (reasonContent.length > 0) {
                    this.reason = this.reason + reasonContent
                    this.updateReasonAt(currentIndex, this.reason)
                  }
                  if (replyContent.length > 0) {
                    this.con = this.con + replyContent
                    this.updateContentAt(currentIndex, this.con)
                  }
                  this.scrollerForScroll.scrollEdge(Edge.Bottom)
                },
                onCompleted: () => {
                  if (this.con.length === 0 && this.reason.length > 0) {
                    this.updateContentAt(currentIndex, this.reason)
                  }
                  this.updateThinkingAt(currentIndex, false)
                  this.num = this.num + 1
                  this.isSending = false
                }
              }
              await getStreamAI.StreamAI(question, callback)
            })


        }
        .height(60)
        .padding(10)
      }.height('100%')
      .justifyContent(FlexAlign.End)

    }
    .backgroundColor('#E2F0FF')
    .height('100%')
    .width('100%')
  }
}
