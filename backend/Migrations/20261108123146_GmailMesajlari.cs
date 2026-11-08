using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class GmailMesajlari : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GmailMesajlari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    GmailKimligi = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    IslenmeAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Sonuc = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    OneriSayisi = table.Column<int>(type: "integer", nullable: false),
                    Deneme = table.Column<int>(type: "integer", nullable: false),
                    Neden = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Konu = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GmailMesajlari", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GmailMesajlari_GmailKimligi",
                table: "GmailMesajlari",
                column: "GmailKimligi",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GmailMesajlari");
        }
    }
}
